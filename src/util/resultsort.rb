#!/usr/bin/env ruby
# encoding: utf-8
# ODDB::ResultSort -- oddb.org -- 28.02.2012 -- mhatakeyama@ywesee.com
# ODDB::ResultSort -- oddb.org -- 10.09.2003 -- mhuggler@ywesee.com

module ODDB
	module ResultStateSort
		def sort
			get_sortby!
      if @model
        @model.each { |atc| 
          atc.packages.sort! { |a, b| compare_entries(a, b) }
          atc.packages.reverse! if(@sort_reverse)
        }
      end
			self
		end
	end
	module ResultSort
		def sort_result(packages, session)
			begin
				packages.sort_by { |package|
					[
						package.expired? ? 1 : -1,
						generic_type_weight(package),
						package.name_base.to_s,
						package.galenic_forms.collect { |gf| galform_str(gf, session) },
						dose_value(package.dose),
						package.comparable_size,
					]
				}
			rescue StandardError => e
				puts e.class
				puts e.message
				puts e.backtrace
				packages
			end
		end
		def dose_value(dose)
			dose || Dose.new(0)
		end
		def package_count
			@packages.size
		end
		def galform_str(galform, session)
			if(galform.odba_instance.nil?)
				''
      elsif galform.respond_to?(session.language.to_sym)
				galform.send(session.language)
      else
        ''
			end
		end
		def generic_type_weight(package)
			case package.generic_type.to_sym
			when :original
				0
			when :generic
				5
			when :comarketing
				10
			when :complementary
				15
			else
				20
			end
			# the following was madly inefficient!
=begin
			types = session.valid_values(:generic_type)
			index = types.index(package.generic_type.to_s).to_i
			10 - (index*2)
=end
		end
	end
end
