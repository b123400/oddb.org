#!/usr/bin/env ruby
# encoding: utf-8
# ODDB::View::Drugs::ResultLimit -- oddb -- 27.07.2012 -- yasaka@ywesee.com
# ODDB::View::Drugs::ResultLimit -- oddb -- 26.07.2005 -- hwyss@ywesee.com

require 'view/resulttemplate'
require 'view/limit'
require 'view/drugs/result'
require 'view/additional_information'
require 'view/dataformat'
require 'view/welcomehead'

module ODDB
	module View
		module Drugs
class ResultLimitList < HtmlGrid::List
	include DataFormat
	include View::AdditionalInformation
	COMPONENTS = {
    [0,0]  => :minifi,
    [1,0]  => :prescription,
		[2,0]	 => :fachinfo,
		[3,0]	 =>	:patinfo,
		[4,0]	 =>	:narcotic,
		[5,0]	 =>	:name_base,
		[6,0]	 =>	:galenic_form,
		[7,0]	 =>	:comparable_size,
		[8,0]	 =>	:price_exfactory,
		[9,0]	 =>	:price_public,
		[10,0] =>	:ikscat,
		[11,0] =>	:feedback,
		[12,0] => :google_search,
		[13,0] =>	:notify,
	}
	DEFAULT_CLASS = HtmlGrid::Value
	CSS_CLASS = 'composite'
	SORT_HEADER = false
	CSS_MAP = {
		[0,0,5]	 => 'list',
		[5,0]    => 'list big',
		[6,0]    => 'list',
		[7,0,4]  => 'list right',
		[11,0,3] => 'list right',
	}
	CSS_HEAD_MAP = {
		[7,0]  => 'th right',
		[8,0]  => 'th right',
		[9,0]  => 'th right',
		[10,0] => 'th right',
		[11,0] => 'th right',
		[12,0] => 'th right',
		[13,0] => 'th right',
	}
	def compose_empty_list(offset)
		count = @session.state.package_count.to_i
		if(count > 0)
			@grid.add(@lookandfeel.lookup(:query_limit_empty, 
				@session.state.package_count, 
				@session.class.const_get(:QUERY_LIMIT)), *offset)
			@grid.add_attribute('class', 'list', *offset)
			@grid.set_colspan(*offset)
		else
			super
		end
	end
  def prescription(model, session)
    super(model, session, 'list important')
  end
	def fachinfo(model, session)
		super(model, session, 'square important infos')
	end	
	def name_base(model, session)
		model.name_base
	end
  def most_precise_dose(model, session=@session)
    model.pretty_dose || if(model.active_agents.size == 1)
      model.dose
    end
  end
end
class ResultLimitComposite < HtmlGrid::Composite
	COMPONENTS = {
		[0,0]	=> SearchForm,
		[0,1] => ResultLimitList, 
		[0,2]	=> View::LimitComposite,
	}
	LEGACY_INTERFACE = false
  CSS_MAP = {
    [0,0] => 'right',
  }
end
class ResultLimit < ResultTemplate
	HEAD = View::WelcomeHead
	CONTENT = ResultLimitComposite
end
		end
	end
end
