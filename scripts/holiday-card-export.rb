#!/usr/bin/env ruby

require 'pathname'
require 'json'

args = ARGV.flat_map { |s| s.scan(/--?([^=\s]+)(?:=(\S+))?/) }.to_h
help = <<-HELP
re:connect holiday card exporter
usage: #{__FILE__} [--instance=INSTANCE_NAME] [--base=BASE_DIR]

will always create a new directory named after the instance
within the base directory!
HELP

if args.key?('help') || args.key?('help')
  puts help
  exit
elsif args['instance'].nil? || args['base'].nil?
  puts help
  exit
end

instance = args['instance']
outdir = Pathname.new(args['base']).expand_path / instance

puts "========================================"
puts "=== re:connect holiday card exporter ==="
puts "========================================"
puts "instance: #{instance.inspect}"
puts "out dir: #{outdir.to_s}"
puts "----------------------------------------"

require 'dotenv/load'
require File.expand_path("../../config/reconnect.rb", __FILE__)
ReConnect.initialize
outdir.mkpath

cardids = []
cardcount = {}
ReConnect::Models::Correspondence.select(:id, :card_instance, :card_status).where(card_instance: instance).each do |cc|
  cardcount[cc.card_status] = (cardcount[cc.card_status] || 0) + 1
  cardids << cc.id if cc.card_status == 'generated'
end

puts "card counts:"
cardcount.each do |k, v|
  puts " - #{k}: #{v}"
end

puts "----------------------------------------"

if cardids.empty?
  puts "!! no cards to export!"
else
  puts "exporting #{cardids.count} generated cards..."
  cardids.each do |ccid|
    cc = ReConnect::Models::Correspondence[ccid]
    next unless cc
    file = ReConnect::Models::File.where(file_id: cc.card_file_id).first
    next unless file
    outfn = file.generate_fn
    (outdir / outfn).open('wb') { |fh| fh.write(file.decrypt_file) }
    puts "written ccid #{ccid} as #{outfn}"
    cc.update(card_status: 'exported')
  end
end

if (cardcount["exported"] || 0) == 0
  puts "!! no already exported cards, skipping address list generation!"
else
  addrh = ReConnect::Models::Prison.all.map { |pr| [pr.id.to_s, pr.decrypt(:physical_address)]}.to_h
  penpalids = ReConnect::Models::Correspondence.where(card_instance: instance, card_status: 'exported').map(&:receiving_penpal).to_a.uniq

  puts "generating address list for #{penpalids.count} incarcerated penpals..."
  addrdata = penpalids.map do |ppid|
    pp = ReConnect::Models::Penpal[ppid]
    prn = pp.decrypt(:prisoner_number)&.strip
    next if prn.nil? || prn&.empty?
    name = [ pp.get_name.map(&:strip).reject(&:empty?).join(' '), "##{prn}" ].join(', ')
    pris = addrh[pp.decrypt(:prison_id).to_s] #  [ name, addrh[pp.decrypt(:prison_id).to_s] ]
    next if pris.nil? || pris&.empty?
    [ name, pris ]
  end.compact

  puts "writing address list to search_results_manual.json"
  (outdir / "search_results_manual.json").open('w') do |fh|
    fh.write(JSON.generate(addrdata.sort { |a, b| b <=> a }))
  end
end

puts "done!"
