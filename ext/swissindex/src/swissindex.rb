#!/usr/bin/ruby
# encoding: utf-8
# ODDB::Swissindex::SwissindexPharma -- 02.10.2012 -- yasaka@ywesee.com
# ODDB::Swissindex::SwissindexPharma -- 10.02.2012 -- mhatakeyama@ywesee.com

require 'rubygems'
require 'savon'
require 'mechanize'
require 'drb'
require 'config'

module ODDB
  module Swissindex
    def Swissindex.session(type = SwissindexPharma)
      yield(type.new)
    end

module Archiver
  def historicize(filename, archive_path, content, lang = 'DE')
    save_dir = File.join archive_path, 'xml'
    FileUtils.mkdir_p save_dir
    archive = File.join save_dir,
                        Date.today.strftime(filename.gsub(/\./,"-#{lang}-%Y.%m.%d."))
    latest  = File.join save_dir,
                        Date.today.strftime(filename.gsub(/\./,"-#{lang}-latest."))
    File.open(archive, 'w') do |f|
      f.puts content
    end
    FileUtils.cp(archive, latest)
  end
end

class RequestHandler
  def initialize(wsdl_url = "https://index.ws.e-mediat.net/Swissindex/NonPharma/ws_NonPharma_V101.asmx?WSDL")
    @client = Savon.client(
      :wsdl => wsdl_url,
      :log => false,
      :log_level => :info,
      :open_timeout => 1,
      :read_timeout => 1,
      )
    @items = []
  end
  def cleanup_items
    @items = []
  end
  def logger(file, options={})
    project_root = File.expand_path('../../..', File.dirname(__FILE__))
    log_dir      = File.expand_path("doc/sl_errors/#{Time.now.year}/#{"%02d" % Time.now.month.to_i}", project_root)
    log_file     = File.join(log_dir, file)
    create_file = if File.exist?(log_file)
                    mtime = File.mtime(log_file)
                    last_update = [mtime.year, mtime.month, mtime.day].join.to_s
                    now = Time.new
                    today = [now.year, now.month, now.day].join.to_s
                    last_update != today
                  else
                    true
                  end
    FileUtils.mkdir_p log_dir
    wa = create_file ? 'w' : 'a'
    open(log_file, wa) do |out|
      if options.has_key?(:code)
        if create_file
          out.print "The following packages (gtin or pharmacode) are not updated (probably because of no response from swissindex server).\n"
          out.print "The second possibility is that the pharmacode is not found in the swissindex server.\n\n"
        end
        out.print "#{options[:type]}: #{options[:code]} (#{Time.new})\n"
      elsif options.has_key?(:error)
        out.print "#{options[:type]}: #{options[:error]} (#{Time.new})\n"
      else
        out.print "#{options[:type]}: (#{Time.new})\n"
      end
    end
    return nil
  end
end

class SwissindexNonpharma < RequestHandler
  URI = 'druby://localhost:50002'
  include DRb::DRbUndumped
  include Archiver
  attr_accessor :client, :base_url
  def initialize
    super
    @base_url = ODDB.config.migel_base_url
  end
  def download_all(lang = 'DE')
    @client.globals[:read_timeout]=120
    try_time = 3
    begin
      soap =
      '<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <lang xmlns="http://swissindex.e-mediat.net/SwissindexNonPharma_out_V101">' + lang + '</lang>
        </soap:Body>
      </soap:Envelope>'
      response = @client.call(:download_all, :xml => soap)
      cleanup_items
      if response.success?
        if xml = response.to_xml
          archive_path = File.expand_path('../../../../migel/data', File.dirname(__FILE__))
          unless Dir.exist?(archive_path)
            archive_path = File.expand_path('../../../data', File.dirname(__FILE__))
          end
          historicize("XMLSwissindexNonPharma.xml", archive_path, xml, lang)
          @items = response.to_hash[:nonpharma][:item]
          return true
        else
          # received broken data or unexpected error
          raise StandardError
        end
      else
        # timeout or unexpected error
        raise StandardError
      end
    rescue StandardError, Timeout::Error => err
      if try_time > 0
        sleep 10
        try_time -= 1
        retry
      else
        cleanup_items
        return false
      end
    end
  end
  def check_item(pharmacode, lang = 'DE')
    item = {}
    @items.each do |i|
      if i.has_key?(:phar) and
         pharmacode == i[:phar]
        item = i
      end
    end
    case
    when item.empty?
      return nil
    when item[:status] == "I"
      return false
    else
      nonpharmaitem = if item.is_a? Array
                        item.sort_by{|p| p[:gtin].to_i}.reverse.first
                      elsif item.is_a? Hash
                        item
                      end
      return nonpharmaitem
    end
  end
  def search_item(pharmacode, lang = 'DE')
    lang.upcase!
    try_time = 3
    begin
      soap = '<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
            <pharmacode xmlns="http://swissindex.e-mediat.net/SwissindexNonPharma_out_V101">' + pharmacode + '</pharmacode>
            <lang xmlns="http://swissindex.e-mediat.net/SwissindexNonPharma_out_V101">' + lang + '</lang>
        </soap:Body>
      </soap:Envelope>'
      response = @client.call(:get_by_pharmacode, :xml => soap)
      if nonpharma = response.to_hash[:nonpharma]
        nonpharma_item = if nonpharma[:item].is_a?(Array)
                           nonpharma[:item].sort_by{|item| item[:gtin].to_i}.reverse.first
                         elsif nonpharma[:item].is_a?(Hash)
                           nonpharma[:item]
                         end
 
        return nonpharma_item
      else
        return nil
      end

    rescue StandardError, Timeout::Error => err
      if try_time > 0
        sleep 10
        try_time -= 1
        retry
      else
        return nil
      end
    end
  end
  def search_migel(pharmacode, lang = 'DE')
    agent = Mechanize.new
    try_time = 3
    begin
      agent.get(@base_url.gsub(/DE/, lang) + 'Pharmacode=' + pharmacode)
      count = 100
      line = []
      agent.page.search('td').each_with_index do |td, i|
        text = td.inner_text.chomp.strip
        if text.is_a?(String) && text.length == 7 && text == pharmacode
          count = 0
        end
        if count < 7
          text = text.split(/\n/)[1] || text.split(/\n/)[0]
          text = text.gsub(/\302\240/, '').strip if text
          line << text
          count += 1
        end
      end
      line
    rescue StandardError, Timeout::Error => err
      if try_time > 0
        sleep 10
        agent = Mechanize.new
        try_time -= 1
        retry
      else
        return []
      end
    end
  end
  def merge_swissindex_migel(swissindex_item, migel_line)
    # Swissindex data
    swissindex = swissindex_item.collect do |key, value|
      case key
      when :gtin
        [:ean_code, value]
      when :dt
        [:datetime, value]
      when :lang
        [:language, value]
      when :dscr
        [:article_name, value]
      when :addscr
        [:size, value]
      when :comp
        [:companyname, value[:name], :companyean, value[:gln]]
      else
        [key, value]
      end
    end
    swissindex = Hash[*swissindex.flatten]

    # Migel data
    pharmacode, article_name, companyname, ppha, ppub, factor, pzr = *migel_line
    migel = {
      :pharmacode   => pharmacode,
      :article_name => article_name,
      :companyname  => companyname,
      :ppha         => ppha,
      :ppub         => ppub,
      :factor       => factor,
      :pzr          => pzr,
    }
    migel.update swissindex
  end
  # 'MiGelCode' is also available for query_key
  def search_migel_table(code, query_key = 'Pharmacode', lang = 'DE')
    # prod.ws.e-mediat.net use untrusted ssl cert
    agent = Mechanize.new { |a|
      a.ssl_version, a.verify_mode = 'SSLv3',
      OpenSSL::SSL::VERIFY_NONE
    }
    try_time = 3
    begin
      agent.get(@base_url.gsub(/DE/,lang) + query_key + '=' + code)
      count = 100
      table = []
      line  = []
      migel = {}
      agent.page.search('td').each_with_index do |td, i|
        text = td.inner_text.chomp.strip
        if text.is_a?(String) && text.length == 7 && text.match(/\d{7}/) 
          migel_item = if pharmacode = line[0] and pharmacode.match(/\d{7}/) and swissindex_item = check_item(pharmacode, lang)
                         merge_swissindex_migel(swissindex_item, line)
                       else
                         merge_swissindex_migel({}, line)
                       end
          table << migel_item
          line = []
          count = 0
        end
        if count < 7 
          text = text.split(/\n/)[1] || text.split(/\n/)[0]
          text = text.gsub(/\302\240/, '').strip if text
          line << text
          count += 1
        end
      end

      # for the last line
      migel_item = if pharmacode = line[0] and pharmacode.match(/\d{7}/) and swissindex_item = check_item(pharmacode, lang)
                     merge_swissindex_migel(swissindex_item, line)
                   else
                     merge_swissindex_migel({}, line)
                   end
      table << migel_item
      table.shift
      table
    rescue StandardError, Timeout::Error => err
      if try_time > 0
        sleep 10
        agent = Mechanize.new
        try_time -= 1
        retry
      else
        return []
      end
    end
  end
  def search_item_with_swissindex_migel(pharmacode, lang = 'DE')
    migel_line = search_migel(pharmacode, lang)
    if swissindex_item = search_item(pharmacode, lang)
      merge_swissindex_migel(swissindex_item, migel_line)
    else
      merge_swissindex_migel({}, migel_line)
    end
  end
  def search_migel_position_number(pharmacode, lang = 'DE')
    agent = Mechanize.new
    try_time = 3
    begin
      agent.get(@base_url.gsub(/DE/, lang) + 'Pharmacode=' + pharmacode)
      pos_num = nil
      agent.page.search('td').each_with_index do |td, i|
        if i == 6
          pos_num = td.inner_text.chomp.strip
          break
        end
      end
      return pos_num
    rescue StandardError, Timeout::Error => err
      if try_time > 0
        sleep 10
        agent = Mechanize.new
        try_time -= 1
        retry
      else
        return nil
      end
    end
  end
end

class SwissindexPharma < RequestHandler
  URI = 'druby://localhost:50001'
  include DRb::DRbUndumped
  include Archiver
  def initialize
   super("https://index.ws.e-mediat.net/Swissindex/Pharma/ws_Pharma_V101.asmx?WSDL")
  end

  def download_all(lang = 'DE')
    @client.globals[:read_timeout]=120

    try_time = 3
    begin
      cleanup_items
      soap =
      '<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <lang xmlns="http://swissindex.e-mediat.net/SwissindexPharma_out_V101">' + lang + '</lang>
        </soap:Body>
      </soap:Envelope>'
      response = @client.call(:download_all, :xml => soap)
      if response.success?
        if xml = response.to_xml
          archive_path = File.expand_path('../../../data', File.dirname(__FILE__))
          historicize("XMLSwissindexPharma.xml",archive_path, xml, lang)
          @items = response.to_hash[:pharma][:item]
          return true
        else
          # received broken data or unexpected error
          raise StandardError
        end
      else
        # timeout or unexpected error
        raise StandardError
      end
    rescue StandardError, Timeout::Error => err
      if try_time > 0
        sleep 10
        try_time -= 1
        retry
      else
        cleanup_items
        options = {
          :type  => :download_all.to_s,
          :error => err
        }
        return logger('bag_xml_swissindex_pharmacode_download_all_error.log', options);
      end
    end
  end
  def check_item(code, check_type = :gtin, lang = 'DE')
    item = {}
    @items.each do |i|
      if i.has_key?(check_type) and
         code == i[check_type]
        item = i
      end
    end
    case
    when item.empty?
      return nil
    when item[:status] == "I"
      return false
    else
      # If there are some products those phamarcode is same, then the return value become an Array
      # We take one of them which has a higher Ean-Code
      pharmacode = if item.is_a? Array
                     item.sort_by{|p| p[:gtin].to_i}.reverse.first[:phar]
                   elsif item.is_a? Hash
                     item[:phar]
                   end
      return pharmacode
    end
  end
  def search_item(code, search_type = :get_by_gtin, lang = 'DE')
    try_time = 3
    begin
      soap = if search_type == :get_by_gtin
      '<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <GTIN xmlns="http://swissindex.e-mediat.net/SwissindexPharma_out_V101">' + code + '</GTIN>
          <lang xmlns="http://swissindex.e-mediat.net/SwissindexPharma_out_V101">' + lang    + '</lang>
        </soap:Body>
      </soap:Envelope>'
              elsif search_type == :get_by_pharmacode
      '<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          <pharmacode xmlns="http://swissindex.e-mediat.net/SwissindexPharma_out_V101">' + code + '</pharmacode>
          <lang xmlns="http://swissindex.e-mediat.net/SwissindexPharma_out_V101">' + lang    + '</lang>
        </soap:Body>
      </soap:Envelope>'
      end
      response = @client.call(search_type, :xml => soap)
      if pharma = response.to_hash[:pharma]
        # If there are some products those phamarcode is same, then the return value become an Array
        # We take one of them which has a higher Ean-Code
        pharma_item = if pharma[:item].is_a?(Array)
                        pharma[:item].sort_by{|item| item[:gtin].to_i}.reverse.first
                      elsif pharma[:item].is_a?(Hash)
                        pharma[:item]
                      end
        return pharma_item
      else
        # Pharmacode is not found in request result by ean(GTIN) code
        return {}
      end
    rescue StandardError, Timeout::Error => err
      if try_time > 0
        sleep 10
        try_time -= 1
        retry
      else
        options = {
          :type => search_type.to_s.gsub('gen_by_', ''),
          :code => code
        }
        return logger('bag_xml_swissindex_pharmacode_error.log', options)
      end
    end
  end
end

  end # Swissindex
end # ODDB
