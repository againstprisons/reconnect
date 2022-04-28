require 'rcpdflayout'

class ReConnect::Workers::AddressStickerGenerateWorker
  include Sidekiq::Worker

  def perform(job_id)
    ReConnect.initialize if ReConnect.app.nil?
    ReConnect.app_config_refresh(:force => true)

    job = ReConnect::Models::AddressStickerJob[job_id.to_i]
    return logger.fatal("Failed to get AddressStickerJob[#{job_id.to_i}]") unless job
    return logger.fatal("AddressStickerJob[#{job.id}] - not pending, bailing") unless job.status == 'pending'

    page_ppi = ReConnect.app_config['rcpdflayout-default-ppi'].to_i
    default_pagesize = RcPdfLayout.const_get(ReConnect.app_config['rcpdflayout-default-page-size-constant'])

    begin
      job.update(status: 'working')

      # Get source file content
      source = ReConnect::Models::File.where(file_id: job.source_file_id).first&.decrypt_file
      source = nil if source&.empty?
      raise "source file couldn't be decrypted or was empty" unless source

      # Parse source file as JSON
      source = JSON.parse(source)

      # Create a document
      document = RcPdfLayout::Document.new

      # Start sheet generation
      if job.page_type == '__list__'
        # TODO: make this use more than one page
        textbox = RcPdfLayout::Object::TextBox.new([10, 10], [-20, -20], page_ppi)
        textbox.text_segment_lines = source.map do |addy|
          RcPdfLayout::TextMarkup.parse_segments("^(b)#{addy.first}^(b) - #{addy.last}")
        end

        page = RcPdfLayout::Object::Page.new(default_pagesize, page_ppi)
        page.children << textbox

        document.pages << page

      else
        sheet_types = ReConnect.app_config['stickersheet-layouts']
        raise "unknown page type #{job.page_type.inspect}" unless sheet_types.key?(job.page_type)

        sheet_desc = sheet_types[job.page_type]
        sheet_pagesize = sheet_desc['page_size']
        sheet_pagesize = RcPdfLayout.const_get(sheet_pagesize) if sheet_pagesize.is_a?(String)
        sheet_per_page = sheet_desc['bounds'].count

        page_addresses = source.each_slice(sheet_per_page).to_a
        page_addresses.map do |chunk|
          page = RcPdfLayout::Object::Page.new(sheet_pagesize, page_ppi)

          chunk.each_with_index do |addy, idx|
            textbox = RcPdfLayout::Object::TextBox.new(
              sheet_desc['bounds'][idx]['position'],
              sheet_desc['bounds'][idx]['size'],
              page_ppi,
              font_size: 10,
            )

            textbox.text_segment_lines = [
              [{ word: addy.first, tags: {'b' => []} }],
              RcPdfLayout::TextMarkup.parse_segments(addy.last || ''),
            ]

            page.children << textbox
          end

          document.pages << page
        end
      end

      # Save document to a temporary file that we can then import
      tmpfile = Tempfile.new(['reconnect-address-label', '.pdf'])
      tmpfile.close
      document.write(tmpfile.path)

      # Import that into a re:connect encrypted file
      tmpfile.open
      file = ReConnect::Models::File.upload(tmpfile.read, filename: "reconnect-address-label_#{Time.now.to_i}.pdf")
      
      # Update the job as ready
      job.update(file_id: file.file_id, status: 'ready')

    rescue => e
      logger.error("AddressStickerJob[#{job.id}] - exception, updating to status=error and raising")
      job.update(status: 'error')
      raise e
    end
  end
end
