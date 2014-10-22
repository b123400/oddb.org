#!/usr/bin/env ruby
# encoding: utf-8

$: << File.expand_path('../../src', File.dirname(__FILE__))
$: << File.expand_path('../..', File.dirname(__FILE__))

gem 'minitest'
require 'minitest/autorun'
require 'fileutils'
require 'flexmock'
require 'plugin/text_info'
require 'model/text'
require 'model/atcclass'
require 'model/registration'

module ODDB
	class FachinfoDocument
		def odba_id
			1
		end
	end
  module SequenceObserver
    def initialize
    end
    def select_one(param)
    end
  end

  class TextInfoPlugin < Plugin
    attr_accessor :parser, :iksless, :session_failures, :current_search,
                  :current_eventtarget
    def read_packages
      @packages = { '32917' => 'Zyloric®'} 
    end    
  end

  class TestTextInfoPluginAipsMetaData <MiniTest::Test
    include FlexMock::TestCase
    unless defined?(@@datadir)
      @@datadir = File.expand_path '../data/xml', File.dirname(__FILE__)
      @@vardir = File.expand_path '../var/', File.dirname(__FILE__)
    end
    
    NrRegistration      = 4
    Test_57435_Iksnr    = '57435'
    Test_57435_Name     = 'Baraclude®'
    Test_57435_Atc      = 'J05AF10'
    Test_57435_Inhaber  = 'Bristol-Myers Squibb SA'   
    Test_57435_Substance= 'Entecavir'
    Test_Iksnr = '62630'
    Test_Name  = 'Xeljanz'
    Test_Atc   = 'L04AA29'
    
    def run_import(iksnr)
      opts ||= {
        :target   => [:fi],
        :reparse  => false,
        :iksnrs   => [iksnr],
        :companies => [],
        :download => false,
      }
      @plugin = TextInfoPlugin.new(@app, opts)
      agent = @plugin.init_agent
      @plugin.parser = @parser
      @plugin.import_swissmedicinfo(opts)
    end
    
    def setup
      flexmock(ODDB::SequenceObserver) do 
        |klass|
        klass.should_receive(:set_oid).and_return('oid')
        klass.should_receive(:new).and_return('new')
      end
      flexstub(ODDB::Persistence) do |klass|
        klass.should_receive(:set_oid).and_return('oid')
      end
      FileUtils.mkdir_p @@vardir
      ODDB.config.data_dir = @@vardir
      ODDB.config.log_dir = @@vardir
      @dest = File.join(@@vardir, 'xml', 'AipsDownload_latest.xml')
      FileUtils.makedirs(File.dirname(@dest))
      FileUtils.cp(File.join(@@datadir, 'AipsDownload_xeljanz.xml'), @dest)
      @package  = flexmock('package')
      @sequence = flexmock('sequence',
                           :packages => ['packages'],
                           :pointer => 'pointer',
                           :creator => 'creator')
      @sequence.should_receive(:create_package).and_return(@package)
      @pointer = flexmock('pointer', :+ => @sequence)
      @company = flexmock('company',
                          :pointer => 'pointer')
      @registration = flexmock('registration1',
                               :pointer => @pointer,
                               :export_flag => false,
                               :inactive? => false,
                               :expiration_date => false,
                               :packages => [@package],
                               :package => @package,
                               :store => 'store')
      @registration.should_receive(:sequence).and_return(@sequence)
      @registrations = flexmock('registrations')
      @registrations.should_receive(:include?).and_return(true)
      @registrations.should_receive(:store).and_return(true)
      @registrations.should_receive(:sequence).and_return(@sequence)
      @registrations.should_receive(:size).once.and_return(2)
      @app = flexmock('application', 
                      :update => @registration, 
                      :delete => 'delete',
                      :registrations => @registrations,).by_default
      @app.should_receive(:textinfo_swissmedicinfo_index)
      @parser = flexmock 'parser (simulates ext/fiparse for swissmedicinfo_xml)'
      @app.should_receive(:registration).with(Test_57435_Iksnr).and_return(@registration)
      @app.should_receive(:registration).with(Test_Iksnr).and_return(@registration)
      @app.should_receive(:registration).with("57436").and_return(@registration)
      @app.should_receive(:registration).with("32917").and_return(@registration)
      @fi_path_de = File.join(@@vardir, "html/fachinfo/de/#{Test_Name}_swissmedicinfo.html")
      @fi_path_fr = File.join(@@vardir, "html/fachinfo/fr/#{Test_Name}_swissmedicinfo.html")    
    end
    
    def teardown
      super
    end

    def test_import_new_registration_xeljanz_from_swissmedicinfo_xml
      reg = flexmock('registration2', 
                     :new => 'new',
                     :store => 'store',
                               :export_flag => false,
                               :inactive? => false,
                               :expiration_date => false,
                     )
      reg.should_receive(:fachinfo).with(Test_Iksnr).and_return(reg)
      ptr = Persistence::Pointer.new([:registration, Test_Iksnr])
      fi = flexmock 'fachinfo'
      flags = {:de => :up_to_date, :fr => :up_to_date}
      @parser.should_receive(:parse_fachinfo_html)

      atc    = ODDB::AtcClass.new(Test_Atc)
      @app.should_receive(:company_by_name).and_return(@company)
      @company.should_receive(:pointer).and_return('pointer')
      # skip("Niklaus does not know whether it is worth mocking this situation")
      assert(run_import(Test_Iksnr), 'must be able to run import_swissmedicinfo and add a new registration')
      meta = TextInfoPlugin::get_iksnrs_meta_info
      refute_nil(meta)
      assert_equal(NrRegistration, meta.size, "we must extract #{NrRegistration} meta info from 2 medicalInformation")
      expected =  SwissmedicMetaInfo.new(Test_Iksnr, Test_Atc, Test_Name, "Pfizer AG", "Tofacitinibum")
      assert_equal(expected, meta[Test_Iksnr], 'Meta information about Test_Iksnr must be correct')
      assert_equal(2, @app.registrations.size)
    end
    
    # Here we used to much memory
    def test_import_57435_baraclude_from_swissmedicinfo_xml
      reg = flexmock('registration3', 
                     :new => 'new',
                     :store => 'store',
                     )
      reg.should_receive(:fachinfo)
      ptr = Persistence::Pointer.new([:registration, Test_57435_Iksnr])
      fi = flexmock 'fachinfo'
      flags = {:de => :up_to_date, :fr => :up_to_date}
      @parser.should_receive(:parse_fachinfo_html)

      atc    = ODDB::AtcClass.new(Test_57435_Atc)
      @app.should_receive(:company_by_name).and_return(@company)
      @company.should_receive(:pointer).and_return('pointer')
      assert(run_import(Test_57435_Iksnr), 'must be able to run import_swissmedicinfo and add a new registration')
      meta = TextInfoPlugin::get_iksnrs_meta_info
      refute_nil(meta)
      assert_equal(NrRegistration, meta.size, "we must extract #{NrRegistration} meta info from 2 medicalInformation")
      expected =  SwissmedicMetaInfo.new(Test_57435_Iksnr, Test_57435_Atc, Test_57435_Name, Test_57435_Inhaber, Test_57435_Substance)
      assert_equal(expected, meta[Test_57435_Iksnr], 'Meta information about Test_57435_Iksnr must be correct')
      assert_equal(2, @app.registrations.size)
    end
  end
  
  class TestTextInfoPlugin <MiniTest::Test
    unless defined?(@@datadir)
      @@datadir = File.expand_path '../data/xml', File.dirname(__FILE__)
      @@vardir = File.expand_path '../var/', File.dirname(__FILE__)
    end
    include FlexMock::TestCase
    
    def create(dateiname, content)
        FileUtils.makedirs(File.dirname(dateiname))
        ausgabe = File.open(dateiname, 'w+')
        ausgabe.write(content)
        ausgabe.close
    end
    
    def setup
      FileUtils.mkdir_p @@vardir
      ODDB.config.data_dir = @@vardir
      ODDB.config.log_dir = @@vardir
      @opts = {
        :target   => [:fi],
        :reparse  => false,
        :iksnrs   => ['32917'], # auf Zeile 2477310: 1234642 2477314
        :companies => [],
        :download => false,
        :xml_file => File.join(@@datadir, 'AipsDownload.xml'), 
      }
      @sequence = flexmock('sequence',
                           :packages => ['packages'],
                           :pointer => 'pointer',
                           :creator => 'creator')
      seq_ptr = flexmock('seq_ptr',
                          :pointer => 'seq_ptr.pointer')
      @pointer = flexmock('pointer',
                          :pointer => seq_ptr,
                          :packages => ['packages'])
      @sequence = flexmock('sequence',
                           :creator => @sequence)
      seq_ptr.should_receive(:+).with([:sequence, 0]).and_return(@sequence)
      @app = flexmock('application', 
                      :pointer => @pointer, 
                      :update => @pointer,
                      :unique_atc_class => nil,
                      :delete => 'delete') # , :registration => [])
      @app.should_receive(:textinfo_swissmedicinfo_index)
      @parser = flexmock 'parser (simulates ext/fiparse for swissmedicinfo_xml)'
      pi_path_de = File.join(@@vardir, 'html/patinfo/de/K_nzle_Passionsblume_Kapseln_swissmedicinfo.html')    
      pi_de = PatinfoDocument.new
      pi_path_fr = File.join(@@vardir, 'html/patinfo/fr/Capsules_PASSIFLORE__K_nzle__swissmedicinfo.html') 
      pi_fr = PatinfoDocument.new
      @parser.should_receive(:parse_patinfo_html).with(pi_path_de, :swissmedicinfo, "Künzle Passionsblume Kapseln").and_return pi_de
      @parser.should_receive(:parse_patinfo_html).with(pi_path_fr, :swissmedicinfo, "Capsules PASSIFLORE \"Künzle\"").and_return pi_de
      @plugin = TextInfoPlugin.new(@app, @opts)
      agent = @plugin.init_agent
      @plugin.parser = @parser
    end # Fuer Problem mit fachinfo italic
    
    def teardown
      FileUtils.rm_rf @@vardir
      super # to clean up FlexMock
    end
    def setup_fachinfo_document heading, text
      fi = FachinfoDocument.new
      fi.iksnrs = Text::Chapter.new
      fi.iksnrs.heading << heading
      fi.iksnrs.next_section.next_paragraph << text
      fi
    end

    def test_import_swissmedicinfo_xml
      reg = flexmock('registration4',
                     :new => 'new',
                     :store => 'store',
                               :export_flag => false,
                               :inactive? => false,
                               :package => :package,
                               :expiration_date => false,
                     )
                     
      reg.should_receive(:fachinfo)
      ptr = Persistence::Pointer.new([:registration, '32917'])
      reg.should_receive(:pointer).and_return ptr
      part = flexmock('part')
      package = flexmock('package', :create_part => part)
      seq = flexmock('sequence',
                     :patinfo= => 'patinfo',
                     :odba_isolated_store => 'odba_isolated_store',
                     :create_package => package,
                     :packages => [package],
                     )
      seq.should_receive(:patinfo)
      seq.should_receive(:pointer).and_return ptr
      reg.should_receive(:each_sequence).and_return do |block| block.call seq end
      reg.should_receive(:sequences).and_return({'01' => seq})
      reg.should_receive(:sequence).and_return(seq)
      reg.should_receive(:packages).and_return([])
      @app.should_receive(:registration).with('32917').and_return reg
      fi = flexmock 'fachinfo'
      fi.should_receive(:pointer).and_return Persistence::Pointer.new([:fachinfo,1])
      pi = flexmock 'patinfo'
      pi.should_receive(:pointer).and_return Persistence::Pointer.new([:patinfo,1])
      flags = {:de => :up_to_date, :fr => :up_to_date}
      @parser.should_receive(:parse_fachinfo_html).once
      @parser.should_receive(:parse_patinfo_html).never
      @plugin.extract_matched_content("Zyloric®", 'fi', 'de')
      assert(@plugin.import_swissmedicinfo(@opts), 'must be able to run import_swissmedicinfo')
    end

    def test_import_swissmedicinfo_no_iksnr
      reg = flexmock('registration4',
                     :new => 'new',
                     :store => 'store',
                               :export_flag => false,
                               :inactive? => false,
                               :package => :package,
                               :expiration_date => false,
                     )
                     
      reg.should_receive(:fachinfo)
      ptr = Persistence::Pointer.new([:registration, '32917'])
      reg.should_receive(:pointer).and_return ptr
      part = flexmock('part')
      package = flexmock('package', :create_part => part)
      seq = flexmock('sequence',
                     :patinfo= => 'patinfo',
                     :odba_isolated_store => 'odba_isolated_store',
                     :create_package => package,
                     :packages => [package],
                     )
      seq.should_receive(:patinfo)
      seq.should_receive(:pointer).and_return ptr
      reg.should_receive(:each_sequence).and_return do |block| block.call seq end
      reg.should_receive(:sequences).and_return({'01' => seq})
      reg.should_receive(:sequence).and_return(seq)
      reg.should_receive(:packages).and_return([])
      @app.should_receive(:registration).with('32917').and_return reg
      fi = flexmock 'fachinfo'
      fi.should_receive(:pointer).and_return Persistence::Pointer.new([:fachinfo,1])
      pi = flexmock 'patinfo'
      pi.should_receive(:pointer).and_return Persistence::Pointer.new([:patinfo,1])
      flags = {:de => :up_to_date, :fr => :up_to_date}
      # only german fachinfo is present
      @parser.should_receive(:parse_fachinfo_html).once
      @parser.should_receive(:parse_patinfo_html).never
      opts = {:iksnrs   => [], :xml_file => File.join(@@datadir, 'AipsDownload.xml')}
      @plugin = TextInfoPlugin.new(@app, opts)
      agent = @plugin.init_agent
      base =  File.expand_path(File.join(__FILE__, '../../../test/data/html/swissmedic/'))
      mappings = { "http://www.swissmedicinfo.ch/Accept.aspx\?ReturnUrl=\%2f" => File.join(base, 'accept.html'),
                   "http://www.swissmedicinfo.ch/?Lang=DE" => File.join(base, 'lang.html'),
                   "http://www.swissmedicinfo.ch/?Lang=FR" => File.join(base, 'lang.html'),
                  }
      @plugin.parser = @parser
      def @plugin.download_swissmedicinfo_xml
        @dest = File.join(@@vardir, 'xml', 'AipsDownload_latest.xml')
        FileUtils.makedirs(File.dirname(@dest))
        FileUtils.cp(File.join(@@datadir, 'AipsDownload_xeljanz.xml'), @dest)
        File.join(@dest, 'AipsDownload_xeljanz.xml')
      end
      def @plugin.textinfo_swissmedicinfo_index
        index = {:new=>{:de=> {:fi=>[["Zyloric®", "Jan 2014"],],
                               :pi=>[["Zyloric®", "Jan 2014"], ],},
                        :fr=>{:fi=>[["Zyloric®", "janv. 2014"],],
                              :pi=>[["Zyloric®", "janv. 2014"],],
                              },
                        },
                 :change=>{:de=> {:fi=>[["Zyloric®", "Jan 2014"],],
                               :pi=>[["Zyloric®", "Jan 2014"], ],},
                        :fr=>{:fi=>[["Zyloric®", "janv. 2014"],],
                              :pi=>[["Zyloric®", "janv. 2014"],],
                              },
                        },
                }
        index
      end
      @app.should_receive(:sorted_fachinfos).and_return([])
      @plugin.extract_matched_content("Zyloric®", 'fi', 'de')
      assert(@plugin.import_swissmedicinfo(), 'must be able to run import_swissmedicinfo')
    end

    def test_import_passion
      name = 'Capsules PASSIFLORE "Künzle"'
      stripped = name # With this line we get the error 
      # Nokogiri::XML::XPath::SyntaxError: Invalid expression: //medicalInformation[@type='pi' and @lang='fr']/title[match(., "Capsules PASSIFLORE "Künzle"")]
      stripped = name.gsub('"','.')
      title = 'Capsules PASSIFLORE "Künzle"'
      type = 'pi'
      lang = 'fr'
      path  = "//medicalInformation[@type='#{type[0].downcase + 'i'}' and @lang='#{lang.to_s}']/title[match(., \"#{stripped}\")]"
      fr = setup_fachinfo_document 'Numéro d’autorisation', '45928 (Swissmedic).'
      @registrations = flexmock('registrations')
      @app.should_receive(:registration).and_return(@registration)
      @company = flexmock('company',
                          :pointer => 'pointer')
      @app.should_receive(:company_by_name).and_return(@company)
      fi_path_fr = File.join(@@datadir, 'passion.fr.xml')
      @doc = @plugin.swissmedicinfo_xml(fi_path_fr)
      match = @doc.xpath(path, Class.new do
        def match(node_set, name)
          found_node = catch(:found) do
            node_set.find_all do |node|
              unknown_chars = /[^A-z0-9,\/\s\-]/
              title = (node.text + '®').gsub(unknown_chars, '')
              name  = name.gsub(unknown_chars, '')
              throw :found, node if title == name
              false
            end
            nil
          end
          found_node ? [found_node] : []
        end
      end.new).first
    end
  end
  class TestTextInfoPluginChecks <MiniTest::Test
    include FlexMock::TestCase
    def setup
      @@datadir = File.expand_path '../data/xml', File.dirname(__FILE__)
      @@vardir = File.expand_path '../var/', File.dirname(__FILE__)
      FileUtils.mkdir_p @@vardir
      ODDB.config.data_dir = @@vardir
      ODDB.config.log_dir = @@vardir
      @opts = {
        :target   => [:fi],
        :reparse  => false,
        :iksnrs   => ['32917'], # auf Zeile 2477310: 1234642 2477314
        :companies => [],
        :download => false,
        :xml_file => File.join(@@datadir, 'AipsDownload.xml'), 
      }
      @app = flexmock('application', :update => @pointer,
                      :delete => 'delete', 
                      :registrations => [],
                      :registration => @registration,
                     )
      @app.should_receive(:registration).with(1, :swissmedicinfo, "Künzle Passionsblume Kapseln").and_return 0
      @app.should_receive(:textinfo_swissmedicinfo_index)
      @parser = flexmock 'parser (simulates ext/fiparse for swissmedicinfo_xml)'
      pi_path_de = File.join(@@vardir, 'html/patinfo/de/K_nzle_Passionsblume_Kapseln_swissmedicinfo.html')    
      pi_de = PatinfoDocument.new
      pi_path_fr = File.join(@@vardir, 'html/patinfo/fr/Capsules_PASSIFLORE__K_nzle__swissmedicinfo.html') 
      pi_fr = PatinfoDocument.new
      @parser.should_receive(:parse_patinfo_html).with(pi_path_de, :swissmedicinfo, "Künzle Passionsblume Kapseln").and_return pi_de
      @parser.should_receive(:parse_patinfo_html).with(pi_path_fr, :swissmedicinfo, "Capsules PASSIFLORE \"Künzle\"").and_return pi_de
      @plugin = TextInfoPlugin.new(@app, @opts)
      agent = @plugin.init_agent
      @plugin.parser = @parser
    end # Fuer Problem mit fachinfo italic
    
    def teardown
      FileUtils.rm_r @@vardir
      super # to clean up FlexMock
    end    
  end
        
  class TestTextInfoPlugin_iksnr <MiniTest::Test
    include FlexMock::TestCase
    def test_get_iksnr_comprimes
      test_string = '59341 (comprimés filmés), 59342 (comprimés à mâcher), 59343 (granulé oral)'
      assert_equal(["59341", "59342", "59343" ], TextInfoPlugin::get_iksnrs_from_string(test_string))
    end
    
    def test_get_iksnr_lopresor
      test_string = "Zulassungsnummer Lopresor 100: 39'252 (Swissmedic) Lopresor Retard 200: 44'447 (Swissmedic)"
      assert_equal(["39252", "44447" ], TextInfoPlugin::get_iksnrs_from_string(test_string))
    end


    def test_get_iksnr_space_at_end
      test_string = '54577 '
      assert_equal(["54577",], TextInfoPlugin::get_iksnrs_from_string(test_string))       
    end
    
    def test_find_iksnr_in_string
      test_string = "54'577, 60’388 "
      assert_equal('54577', TextInfoPlugin.find_iksnr_in_string(test_string, '54577'))
      assert_equal('60388', TextInfoPlugin.find_iksnr_in_string(test_string, '60388'))
    end

    def test_get_iksnr_victrelis
      test_string = "62'105"
      assert_equal(['62105'], TextInfoPlugin::get_iksnrs_from_string(test_string))       
      assert_equal('62105', TextInfoPlugin.find_iksnr_in_string(test_string, '62105'))
    end
    
    def test_get_iksnr_temodal
      test_string = "54'577, 60’388 "
      assert_equal(["54577", '60388'], TextInfoPlugin::get_iksnrs_from_string(test_string))       
    end
   
  end
end 
