#!/usr/bin/env ruby

$: << File.expand_path('../../src', File.dirname(__FILE__))

require 'test/unit'
require 'fileutils'
require 'flexmock'
require 'plugin/text_info'
require 'model/text'

module ODDB
	class FachinfoDocument
		def odba_id
			1
		end
	end
  class TextInfoPlugin
    attr_accessor :parser, :iksless, :session_failures
  end
  class TestTextInfoPlugin < Test::Unit::TestCase
    include FlexMock::TestCase
    def setup
      super
      @app = flexmock 'application'
      @datadir = File.expand_path '../data/html/text_info', File.dirname(__FILE__)
      @vardir = File.expand_path '../var/', File.dirname(__FILE__)
      FileUtils.mkdir_p @vardir
      ODDB.config.data_dir = @vardir
      ODDB.config.text_info_searchform = 'http://textinfo.ch/Search.aspx'
      @parser = flexmock 'parser (simulates ext/fiparse)'
      @plugin = TextInfoPlugin.new @app
      @plugin.parser = @parser
    end
    def teardown
      FileUtils.rm_r @vardir
      super
    end
    def setup_mechanize mapping=[]
      agent = flexmock Mechanize.new
      @pages = Hash.new(0)
      @actions = {}
      mapping.each do |page, method, url, formname, page2|
        path = File.join @datadir, page
        page = setup_page url, path, agent
        if formname
          form = flexmock page.form(formname)
          action = form.action
          page = flexmock page
          page.should_receive(:form).with(formname).and_return(form)
          path2 = File.join @datadir, page2
          page2 = setup_page action, path2, agent
          agent.should_receive(:submit).and_return page2
        end
        case method
        when :get, :post
          agent.should_receive(method).with(url).and_return do |*args|
            @pages[[method, url, *args]] += 1
            page
          end
        when :submit
          @actions[url] = page
          agent.should_receive(method).and_return do |form, *args|
            action = form.action
            @pages[[method, action, *args]] += 1
            @actions[action]
          end
        else
          agent.should_receive(method).and_return do |*args|
            @pages[[method, *args]] += 1
            page
          end
        end
      end
      agent
    end
    def setup_page url, path, agent
      response = {'content-type' => 'text/html'}
      Mechanize::Page.new(URI.parse(url), response,
                          File.read(path), 200, agent)
    end
    def setup_fachinfo_document heading, text
      fi = FachinfoDocument.new
      fi.iksnrs = Text::Chapter.new
      fi.iksnrs.heading << heading
      fi.iksnrs.next_section.next_paragraph << text
      fi
    end
    def test_init_agent
      agent = @plugin.init_agent
      assert_instance_of Mechanize, agent
      assert /Mozilla/.match(agent.user_agent)
    end
    def test_init_searchform__not_configured
      ODDB.config.text_info_searchform = nil
      agent = setup_mechanize
      assert_raises RuntimeError do
        @plugin.init_searchform agent
      end
    end
    def test_init_searchform__accept
      mapping = [
        [ 'AcceptForm.html',
          :get,
          'http://textinfo.ch/Search.aspx',
          'frmNutzungsbedingungen',
          'SearchForm.html',
        ],
      ]
      agent = setup_mechanize mapping
      page = nil
      assert_nothing_raised do
        page = @plugin.init_searchform agent
      end
      assert_not_nil page.form_with :name => 'frmSearchForm'
    end
    def test_search_company
      mapping = [
        [ 'SearchForm.html',
          :get,
          'http://textinfo.ch/Search.aspx',
          'frmSearchForm',
          'Companies.html',
        ],
      ]
      agent = setup_mechanize mapping
      page = nil
      assert_nothing_raised do
        page = @plugin.search_company 'novartis', agent
      end
      assert_not_nil page.form_with :name => 'frmResulthForm'
      assert_equal 1, @pages.size
    end
    def test_import_companies
      ## we return an empty result here, to contain testing the import_companies method
      mapping = [
        [ 'ResultEmpty.html',
          :submit,
          'Result.aspx?lang=de',
        ],
      ]
      agent = setup_mechanize mapping
      path = File.join @datadir, 'Companies.html'
      result = setup_page 'http://textinfo.ch/Search.aspx', path, agent
      page = nil
      assert_nothing_raised do
        @plugin.import_companies result, agent
      end
      ## we've touched only one page here, because we returned ResultEmpty.html
      assert_equal 1, @pages.size
    end
    def test_import_company
      mapping = [
        [ 'SearchForm.html',
          :get,
          'http://textinfo.ch/Search.aspx',
        ],
        [ 'Companies.html',
          :submit,
          'Search.aspx',
        ],
        [ 'ResultAlcaC.html',
          :submit,
          'Result.aspx?lang=de',
        ],
        [ 'Aclasta.de.html',
          :submit,
          'CompanyProdukte.aspx?lang=de',
        ],
        [ 'Aclasta.fr.html',
          :get,
          'CompanyProdukte.aspx?lang=fr',
        ],
      ]
      agent = setup_mechanize mapping
      page = nil
      @parser.should_receive(:parse_fachinfo_html).and_return FachinfoDocument.new
      @parser.should_receive(:parse_patinfo_html).and_return PatinfoDocument.new
      assert_nothing_raised do
        @plugin.import_company 'novartis', agent
      end
      assert_equal 5, @pages.size
      ## we didn't set up @parser to return a FachinfoDocument with an iksnr.
      #  the rest of the process is tested in test_update_product
      assert_equal ['Alca-C®'], @plugin.iksless.uniq
    end
    def test_import_company__session_failure
      mapping = [
        [ 'SearchForm.html',
          :get,
          'http://textinfo.ch/Search.aspx',
        ],
        [ 'Companies.html',
          :submit,
          'Search.aspx',
        ],
        [ 'ResultAlcaC.html',
          :submit,
          'Result.aspx?lang=de',
        ],
        [ 'SearchForm.html',
          :submit,
          'CompanyProdukte.aspx?lang=de',
        ],
        [ 'SearchForm.html',
          :get,
          'CompanyProdukte.aspx?lang=fr',
        ],
      ]
      agent = setup_mechanize mapping
      page = nil
      @parser.should_receive(:parse_fachinfo_html).and_return FachinfoDocument.new
      @parser.should_receive(:parse_patinfo_html).and_return PatinfoDocument.new
      assert_nothing_raised do
        @plugin.import_company 'novartis', agent
      end
      assert_equal 5, @pages.size
      ## we didn't set up @parser to return a FachinfoDocument with an iksnr.
      #  the rest of the process is tested in test_update_product
      assert_equal ['Alca-C®'], @plugin.iksless.uniq
      assert_equal 8, @plugin.session_failures
    end
    def test_identify_eventtargets
      agent = setup_mechanize
      path = File.join @datadir, 'Result.html'
      page = setup_page 'http://textinfo.ch/Search.aspx', path, agent
      targets = @plugin.identify_eventtargets page, /btnFachinformation/
      assert_equal 77, targets.size
      assert_equal "dtgFachinformationen$_ctl2$btnFachinformation", targets['Alca-C®']
      assert_equal "dtgFachinformationen$_ctl78$btnFachinformation",
                   targets['Zymafluor®']
      targets = @plugin.identify_eventtargets page, /btnPatientenn?information/
      assert_equal 79, targets.size
      assert_equal "dtgPatienteninformationen$_ctl2$btnPatientenninformation",
                   targets['Alca-C®']
      assert_equal "dtgPatienteninformationen$_ctl80$btnPatientenninformation",
                   targets['Zymafluor®']
    end
    def test_import_products
      mapping = [
        [ 'Aclasta.de.html',
          :submit,
          'http://textinfo.ch/MonographieTxt.aspx?lang=de&MonType=fi',
        ],
        [ 'Aclasta.fr.html',
          :get,
          'http://textinfo.ch/MonographieTxt.aspx?lang=fr&MonType=fi',
        ]
      ]
      agent = setup_mechanize mapping
      path = File.join @datadir, 'ResultEmpty.html'
      result = setup_page 'http://textinfo.ch/Search.aspx', path, agent
      page = nil
      @parser.should_receive(:parse_fachinfo_html).and_return FachinfoDocument.new
      @parser.should_receive(:parse_patinfo_html).and_return PatinfoDocument.new
      assert_nothing_raised do
        @plugin.import_products result, agent
      end
    end
    def test_download_info
      mapping = [
        [ 'Aclasta.de.html',
          :submit,
          'CompanyProdukte.aspx?lang=de',
        ],
        [ 'Companies.html',
          :get,
          'CompanyProdukte.aspx?lang=fr',
        ]
      ]
      agent = setup_mechanize mapping
      path = File.join @datadir, 'Result.html'
      page = setup_page 'http://textinfo.ch/CompanyProdukte.aspx?lang=de', path, agent
      form = page.form_with :name => 'frmResultProdukte'
      eventtarget = 'dtgFachinformationen$_ctl3$btnFachinformation'
      paths = nil
      assert_nothing_raised do
        paths = @plugin.download_info :fachinfo, 'Aclasta', agent, form, eventtarget
      end
      expected = {}
      path = File.join @vardir, 'html', 'fachinfo', 'de', 'Aclasta.html'
      expected.store :de, path
      assert File.exist?(path)
      path = File.join @vardir, 'html', 'fachinfo', 'fr', 'Aclasta.html'
      expected.store :fr, path
      assert File.exist?(path)
      assert_equal expected, paths
    end
    def test_extract_iksnrs
      de = setup_fachinfo_document 'Zulassungsnummer', '57363 (Swissmedic).'
      fr = setup_fachinfo_document 'Numéro d’autorisation', '57364 (Swissmedic).'
      assert_equal %w{57363 57364}, @plugin.extract_iksnrs(:de => de, :fr => fr).sort
    end
    def test_update_product__new_infos
      de = setup_fachinfo_document 'Zulassungsnummer', '57363 (Swissmedic).'
      fr = setup_fachinfo_document 'Numéro d’autorisation', '57363 (Swissmedic).'
      fi_path_de = File.join(@datadir, 'Aclasta.de.html')
      fi_path_fr = File.join(@datadir, 'Aclasta.fr.html')
      fi_paths = { :de => fi_path_de, :fr => fi_path_fr }
      pi_path_de = File.join(@datadir, 'Aclasta.pi.de.html')
      pi_path_fr = File.join(@datadir, 'Aclasta.pi.fr.html')
      pi_paths = { :de => pi_path_de, :fr => pi_path_fr }
      pi_de = PatinfoDocument.new
      pi_fr = PatinfoDocument.new
      @parser.should_receive(:parse_fachinfo_html).with(fi_path_de).and_return de
      @parser.should_receive(:parse_fachinfo_html).with(fi_path_fr).and_return fr
      @parser.should_receive(:parse_patinfo_html).with(pi_path_de).and_return pi_de
      @parser.should_receive(:parse_patinfo_html).with(pi_path_fr).and_return pi_fr

      reg = flexmock 'registration'
      reg.should_receive(:fachinfo)
      ptr = Persistence::Pointer.new([:registration, '57363'])
      reg.should_receive(:pointer).and_return ptr
      seq = flexmock 'sequence'
      seq.should_receive(:patinfo)
      seq.should_receive(:pointer).and_return ptr + [:sequence, '01']
      reg.should_receive(:each_sequence).and_return do |block| block.call seq end
      reg.should_receive(:sequences).and_return({'01' => seq})
      @app.should_receive(:registration).with('57363').and_return reg
      fi = flexmock 'fachinfo'
      fi.should_receive(:pointer).and_return Persistence::Pointer.new([:fachinfo,1])
      pi = flexmock 'patinfo'
      pi.should_receive(:pointer).and_return Persistence::Pointer.new([:patinfo,1])
      @app.should_receive(:update).and_return do |pointer, data|
        case pointer.to_s
        when ':!create,:!fachinfo..'
          assert_equal({:de => de, :fr => fr}, data)
          fi
        when ':!create,:!patinfo..'
          assert_equal({:de => pi_de, :fr => pi_fr}, data)
          pi
        when ':!registration,57363.'
          assert_equal({:fachinfo => fi.pointer}, data)
          reg
        when ':!registration,57363!sequence,01.'
          assert_equal({:patinfo => pi.pointer}, data)
          seq
        else
          flunk "unhandled call to update(#{pointer})"
        end
      end
      result = @plugin.update_product 'Aclasta', fi_paths, pi_paths
    end
    def test_update_product__existing_infos
      de = setup_fachinfo_document 'Zulassungsnummer', '57363 (Swissmedic).'
      fr = setup_fachinfo_document 'Numéro d’autorisation', '57363 (Swissmedic).'
      fi_path_de = File.join(@datadir, 'Aclasta.de.html')
      fi_path_fr = File.join(@datadir, 'Aclasta.fr.html')
      fi_paths = { :de => fi_path_de, :fr => fi_path_fr }
      pi_path_de = File.join(@datadir, 'Aclasta.pi.de.html')
      pi_path_fr = File.join(@datadir, 'Aclasta.pi.fr.html')
      pi_paths = { :de => pi_path_de, :fr => pi_path_fr }
      pi_de = PatinfoDocument.new
      pi_fr = PatinfoDocument.new
      @parser.should_receive(:parse_fachinfo_html).with(fi_path_de).and_return de
      @parser.should_receive(:parse_fachinfo_html).with(fi_path_fr).and_return fr
      @parser.should_receive(:parse_patinfo_html).with(pi_path_de).and_return pi_de
      @parser.should_receive(:parse_patinfo_html).with(pi_path_fr).and_return pi_fr

      fi = flexmock 'fachinfo'
      fi.should_receive(:pointer).and_return Persistence::Pointer.new([:fachinfo,1])
      fi.should_receive(:empty?).and_return(true)
      pi = flexmock 'patinfo'
      pi.should_receive(:pointer).and_return Persistence::Pointer.new([:patinfo,1])
      ## this is conceptually a bit of a leap, but it tests all the code: even though
      #  pi is used to update the patinfo, I'm making it claim empty?, so that the
      #  deletion-code is triggered
      pi.should_receive(:empty?).and_return(true)
      reg = flexmock 'registration'
      reg.should_receive(:fachinfo).and_return fi
      ptr = Persistence::Pointer.new([:registration, '57363'])
      reg.should_receive(:pointer).and_return ptr
      seq = flexmock 'sequence'
      seq.should_receive(:patinfo).and_return pi
      seq.should_receive(:pointer).and_return ptr + [:sequence, '01']
      reg.should_receive(:each_sequence).and_return do |block| block.call seq end
      reg.should_receive(:sequences).and_return({'01' => seq})
      @app.should_receive(:registration).with('57363').and_return reg
      @app.should_receive(:update).and_return do |pointer, data|
        case pointer.to_s
        when ':!create,:!fachinfo..'
          assert_equal({:de => de, :fr => fr}, data)
          fi
        ## existing patinfos are handled differently than fachinfos!
        when ':!patinfo,1.'
          assert_equal({:de => pi_de, :fr => pi_fr}, data)
          pi
        when ':!registration,57363.'
          assert_equal({:fachinfo => fi.pointer}, data)
          reg
        when ':!registration,57363!sequence,01.'
          assert_equal({:patinfo => pi.pointer}, data)
          seq
        else
          flunk "unhandled call to update(#{pointer})"
        end
      end
      @app.should_receive(:delete).and_return do |pointer, data|
        case pointer.to_s
        when ':!fachinfo,1.'
          assert true
          fi
        when ':!patinfo,1.'
          assert true
          pi
        else
          flunk "unhandled call to delete(#{pointer})"
        end
      end
      result = @plugin.update_product 'Aclasta', fi_paths, pi_paths
    end
    def test_update_product__orphaned_infos
      de = setup_fachinfo_document 'Zulassungsnummer', '57363 (Swissmedic).'
      fr = setup_fachinfo_document 'Numéro d’autorisation', '57363 (Swissmedic).'
      fi_path_de = File.join(@datadir, 'Aclasta.de.html')
      fi_path_fr = File.join(@datadir, 'Aclasta.fr.html')
      fi_paths = { :de => fi_path_de, :fr => fi_path_fr }
      pi_path_de = File.join(@datadir, 'Aclasta.pi.de.html')
      pi_path_fr = File.join(@datadir, 'Aclasta.pi.fr.html')
      pi_paths = { :de => pi_path_de, :fr => pi_path_fr }
      pi_de = PatinfoDocument.new
      pi_fr = PatinfoDocument.new
      @parser.should_receive(:parse_fachinfo_html).with(fi_path_de).and_return de
      @parser.should_receive(:parse_fachinfo_html).with(fi_path_fr).and_return fr
      @parser.should_receive(:parse_patinfo_html).with(pi_path_de).and_return pi_de
      @parser.should_receive(:parse_patinfo_html).with(pi_path_fr).and_return pi_fr

      @app.should_receive(:registration).with('57363')
      @app.should_receive(:update).and_return do |pointer, data|
        case pointer.to_s
        when ":!create,:!orphaned_fachinfo.."
          expected = {
            :key => '57363',
            :languages => { :de => de, :fr => fr },
          }
          assert_equal expected, data
        when ":!create,:!orphaned_patinfo.."
          expected = {
            :key => '57363',
            :languages => { :de => pi_de, :fr => pi_fr },
          }
          assert_equal expected, data
        else
          flunk "unhandled call to update(#{pointer})"
        end
      end
      result = @plugin.update_product 'Aclasta', fi_paths, pi_paths
    end
    def test_detect_session_failure__failure
      agent = setup_mechanize
      path = File.join @datadir, 'SearchForm.html'
      page = setup_page 'CompanyProdukte.aspx?lang=de', path, agent
      assert_equal true, @plugin.detect_session_failure(page)
    end
    def test_detect_session_failure__fine
      agent = setup_mechanize
      path = File.join @datadir, 'Companies.html'
      page = setup_page 'Search.aspx', path, agent
      assert_equal false, @plugin.detect_session_failure(page)
      path = File.join @datadir, 'ResultEmpty.html'
      page = setup_page 'Result.aspx?lang=de', path, agent
      assert_equal false, @plugin.detect_session_failure(page)
      path = File.join @datadir, 'Result.html'
      page = setup_page 'Result.aspx?lang=de', path, agent
      assert_equal false, @plugin.detect_session_failure(page)
      path = File.join @datadir, 'Aclasta.de.html'
      page = setup_page 'CompanyProdukte.aspx?lang=de', path, agent
      assert_equal false, @plugin.detect_session_failure(page)
    end
    def test_rebuild_resultlist
      mapping = [
        [ 'SearchForm.html',
          :get,
          'http://textinfo.ch/Search.aspx',
        ],
        [ 'Companies.html',
          :submit,
          'Search.aspx',
        ],
        [ 'ResultAlcaC.html',
          :submit,
          'Result.aspx?lang=de',
        ],
      ]
      agent = setup_mechanize mapping
      form = @plugin.rebuild_resultlist agent
      assert_instance_of Mechanize::Form, form
      assert_equal 'CompanyProdukte.aspx?lang=de', form.action
    end
  end
end