require 'mini_magick'
require 'rcpdflayout'
require 'rcpdflayout/text_markup/markdown'

class ReConnect::Workers::CorrespondenceCardGenerateWorker
  include Sidekiq::Worker

  def perform(ccid)
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    cc_obj = ReConnect::Models::Correspondence[ccid.to_i]
    return logger.fatal("Failed to get Correspondence[#{ccid.to_i}]") unless cc_obj
    return logger.fatal("Correspondence[#{ccid.to_i}] is not ready for card generation") unless cc_obj.card_status == 'ready'

    page_ppi = ReConnect.app_config['rcpdflayout-default-ppi'].to_i
    default_pagesize = ReConnect.app_config['correspondence-card-default-page-size']
    default_pagesize = RcPdfLayout.const_get(default_pagesize) if default_pagesize.is_a?(String)

    begin
      # update cc_obj to signal we're generating
      cc_obj.update(card_status: 'generating')

      # get the correspondence text
      html_part = ReConnect::Models::File.where(:file_id => cc_obj.file_id).first&.decrypt_file
      html_part = nil if html_part&.strip == ""
      raise "source file couldn't be decrypted or was empty" unless html_part

      # do a sanitize fragment run, just in case
      html_part = Sanitize.fragment(html_part, Sanitize::Config::BASIC)

      # construct plain-text version of the HTML contents using reverse-markdown
      text_part = ReverseMarkdown.convert(html_part, :unknown_tags => :bypass)

      # convert the markdown to rcpdflayout markup
      markup = RcPdfLayout::TextMarkup.parse_from_markdown(text_part)

      # Get cover image
      cover = ReConnect::Models::HolidayCardCover[cc_obj.card_cover]
      raise "HolidayCardCover[#{cc_obj.card_cover}] invalid " unless cover
      cover_file = ReConnect::Models::File.where(file_id: cover.file_id).first
      raise "HolidayCardCover[#{cc_obj.card_cover}] file not found" unless cover_file
      cover_ext = MimeMagic.new(cover_file.mime_type)&.extensions&.first || '.jpg'
      cover_tmpfile = Tempfile.new(['reconnect-holidaycard-cover', cover_ext])
      cover_tmpfile.write(cover_file.decrypt_file)
      cover_tmpfile.close

      # Add cover image to one half of new page
      cover_image = RcPdfLayout::Object::Image.new([0, 0], [default_pagesize.first / 2, default_pagesize.last], page_ppi, defer_image: true)
      cover_image.object_image = MiniMagick::Image.open(cover_tmpfile.path)
      cover_page = RcPdfLayout::Object::Page.new(default_pagesize, page_ppi)
      cover_page.children << cover_image

      # Add text to second half of new page
      text_box = RcPdfLayout::Object::TextBox.new([(default_pagesize.first / 2) + 10, 10], [(default_pagesize.first / 2) - 20, default_pagesize.last - 20], page_ppi)
      text_box.text_segment_lines = markup
      text_page = RcPdfLayout::Object::Page.new(default_pagesize, page_ppi)
      text_page.children << text_box

      # Create document
      document = RcPdfLayout::Document.new
      document.pages << cover_page
      document.pages << text_page

      # Save document to a temporary file that we can then import
      tmpfile = Tempfile.new(['reconnect-holidaycard', '.pdf'])
      tmpfile.close
      document.write(tmpfile.path)

      # Import that into a re:connect encrypted file
      tmpfile.open
      file = ReConnect::Models::File.upload(tmpfile.read, filename: "reconnect-holidaycard_#{Time.now.to_i}.pdf")
      
      # Update the job as ready
      cc_obj.update(card_file_id: file.file_id, card_status: 'generated')

    rescue => e
      logger.error("Correspondence[#{cc_obj.id}] - exception, updating to status=error and raising")
      cc_obj.update(card_status: 'error')
      raise e
    end
  end
end
