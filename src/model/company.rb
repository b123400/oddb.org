#!/usr/bin/env ruby
# encoding: utf-8
# Company -- oddb -- 28.02.2003 -- hwyss@ywesee.com 

require 'util/persistence'
require 'util/today'
require 'model/registration_observer'
require 'model/address'
require 'model/user'

module ODDB
	class Company
		include Persistence
		include RegistrationObserver
		include UserObserver
		include AddressObserver
		ODBA_SERIALIZABLE = ['@addresses', '@invoice_dates', '@disabled_invoices', 
                         '@prices', '@users']
    attr_accessor :address_email, :business_area, :business_unit, :cl_status,
      :competition_email, :complementary_type, :contact, :deductible_display,
      :disable_patinfo, :ean13, :generic_type,
      :invoice_htmlinfos, :logo_filename, :lookandfeel_member_count, :name, 
      :powerlink, :regulatory_email, :swissmedic_email, :swissmedic_salutation,
      :url, :ydim_id, :limit_invoice_duration, :force_new_ydim_debitor
    attr_reader :invoice_dates, :disabled_invoices
		alias :fullname :name
		alias :power_link= :powerlink=
		alias :power_link :powerlink
		alias :to_s :name
		alias :email :address_email
		def initialize
			@addresses = [Address2.new]
			@cl_status = false
      @invoice_dates = {}
      @disabled_invoices = {}
      @prices = {}
			super
		end	
		def init(app)
			@pointer.append(@oid)
		end
		def active_package_count
			@registrations.inject(0) { |sum, reg|
				sum + reg.active_package_count
			}
		end
		def atc_classes
			@registrations.inject([]) do |memo, registration|
				memo.concat registration.atc_classes
      end.compact.uniq
		end
    def disable_invoice_fachinfo
      invoice_disabled?(:fachinfo)
    end
    def disable_invoice_fachinfo=(status)
      @disabled_invoices[:fachinfo] = status
    end
    def disable_invoice_patinfo
      invoice_disabled?(:patinfo)
    end
    def disable_invoice_patinfo=(status)
      @disabled_invoices[:patinfo] = status
    end
    def inactive_packages
      packages.select { |pac|
        (date = pac.market_date) && date > @@today
      }
    end
		def inactive_registrations
			@registrations.reject { |registration|
				registration.public_package_count > 0
			}
		end
    ## to be invoiceable, the company needs to have a complete address:
		def invoiceable?
			addr = address(0)
			![ @name, @contact, addr.address, addr.plz, 
				addr.city, invoice_email, addr.fon ].any? { |datum| datum.nil? }
		end
    def invoice_date(key)
      @invoice_dates[key] = _yearly_repetition(@invoice_dates[key])
    end
    def invoice_date_fachinfo
      invoice_date(:fachinfo)
    end
    def invoice_date_fachinfo=(date)
      @invoice_dates[:fachinfo] = date
    end
    def invoice_date_index
      invoice_date(:index)
    end
    def invoice_date_index=(date)
      @invoice_dates[:index] = date
    end
    def invoice_date_lookandfeel
      invoice_date(:lookandfeel)
    end
    def invoice_date_lookandfeel=(date)
      @invoice_dates[:lookandfeel] = date
    end
    def invoice_date_patinfo
      invoice_date(:patinfo)
    end
    def invoice_date_patinfo=(date)
      @invoice_dates[:patinfo] = date
    end
    def invoice_disabled?(key)
      @disabled_invoices[key]
    end
		def listed?
			@cl_status
		end
		def merge(other)
			other.registrations.dup.each { |reg|
				reg.company = self
				reg.odba_isolated_store
			}
			@registrations.odba_isolated_store
		end
		def pointer_descr
			@name
		end
    def price(key)
      @prices[key]
    end
    def price_fachinfo
      price(:fachinfo)
    end
    def price_fachinfo=(units)
      @prices[:fachinfo] = units
    end
    def price_index
      price(:index)
    end
    def price_index=(cents)
      @prices[:index] = cents
    end
    def price_index_package
      price(:index_package)
    end
    def price_index_package=(cents)
      @prices[:index_package] = cents
    end
    def price_lookandfeel
      price(:lookandfeel)
    end
    def price_lookandfeel=(cents)
      @prices[:lookandfeel] = cents
    end
    def price_lookandfeel_member
      price(:lookandfeel_member)
    end
    def price_lookandfeel_member=(cents)
      @prices[:lookandfeel_member] = cents
    end
    def price_patinfo
      price(:patinfo)
    end
    def price_patinfo=(units)
      @prices[:patinfo] = units
    end
		def search_terms
			terms = @name.split(/[\s\-()]+/u).select { |str| str.size >= 3 }
			terms += [
				@name, @ean13, 
			]
			@addresses.each { |addr| 
				terms += addr.search_terms
			}
			ODDB.search_terms(terms)
		end
    def packages
      @registrations.inject([]) { |memo, reg|
        memo.concat(reg.packages)
      }
    end
		private
		def adjust_types(input, app=nil)
			input.each { |key, val|
				case key
				when :powerlink
					if(val.to_s.empty?)
						input[key] = nil
					end
				when :generic_type, :complementary_type
					if(val.is_a? String)
						input[key] = val.intern
					end
				when :price_lookandfeel, :price_lookandfeel_member, 
					:price_index, :price_index_package
					input[key] = (val.to_f * 100) unless(val.nil?)
				end
			}
			input
		end
		def _yearly_repetition(date)
			if(date)
				while(date < @@today)
					date = date >> 12
				end
				date
			end
		end
	end
end
