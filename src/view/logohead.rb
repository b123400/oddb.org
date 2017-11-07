#!/usr/bin/env ruby
# encoding: utf-8
# ODDB::View::LogoHead -- oddb -- 30.11.2012 -- yasaka@ywesee.com
# ODDB::View::LogoHead -- oddb -- 24.10.2002 -- hwyss@ywesee.com

require 'htmlgrid/composite'
require 'view/sponsorlogo'
require 'view/google_ad_sense'
require 'view/personal.rb'
require 'view/tab_navigation'
require 'view/searchbar'
require 'htmlgrid/link'
require 'view/language_chooser'
require 'view/logo'

module ODDB
	module View
		module SponsorDisplay
			include GoogleAdSenseMethods
			CSS_CLASS = 'composite'
			GOOGLE_CHANNEL = '6336403681'
			GOOGLE_FORMAT = '468x60_as'
			GOOGLE_WIDTH = '468'
			GOOGLE_HEIGHT = '60'
			def sponsor(model, session=@session)
				unless(@session.user.valid?)
					if((spons = @session.sponsor) && spons.valid?)
						View::SponsorLogo.new(spons, session, self)
					elsif(@lookandfeel.enabled?(:google_adsense))
						ad_sense(model, session)
					end
				end
			end
=begin ## unused code: does the sponsor represent at least one product?
			private
			def sponsor_represents?(spons, model)
				model.respond_to?(:any?) \
				&& (date = spons.sponsor_until) \
				&& date >= @@today \
				&& model.any? { |item|
					spons.represents?(item) || (item.respond_to?(:packages) \
						&& item.packages.any? { |pac| spons.represents?(pac)})
				}
			end
=end
		end
    class CommonLogoHead < HtmlGrid::Composite
      include Personal
      include SponsorDisplay
      include UserSettings
    end
    class LogoHead < CommonLogoHead
      COMPONENTS = {
        [0,0]   => View::Logo,
        [0,1]   => :language_chooser,
        [1,1]   => :tab_navigation,
      }
      CSS_MAP = {
        [0,0] => 'logo',
        [0,1] => 'list',
        [1,1] => 'tabnavigation right',
      }
      COMPONENT_CSS_MAP = {
        [0,1] => 'component',
      }
      def language_chooser(model, session=@session)
        unless @lookandfeel.disabled?(:search_result_head_navigation)
          super
        end
      end
      def tab_navigation(model, session=@session)
        unless @lookandfeel.disabled?(:search_result_head_navigation)
          View::TabNavigation.new(model, session, self)
        end
      end
    end
		class PopupLogoHead < CommonLogoHead
			COMPONENTS = {
				[0,0]		=>	View::PopupLogo,
				[1,0]		=>	:sponsor,
			}
			CSS_MAP = {
				[0,0]	=>	'logo',
				[1,0]	=>	'right',
			}
			COMPONENT_CSS_MAP = {}
			GOOGLE_FORMAT = '234x60_as'
			GOOGLE_WIDTH = '234'
			GOOGLE_HEIGHT = '60'
		end
	end
end
