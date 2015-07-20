#!/usr/bin/env ruby
# encoding: utf-8
# View::Admin::ActiveAgent -- oddb -- 22.04.2003 -- hwyss@ywesee.com 

require 'view/drugs/privatetemplate'
require 'view/admin/sequence'
require 'view/form'
require 'htmlgrid/errormessage'
require 'htmlgrid/value'

module ODDB
	module View
		module Admin
class ActiveAgentInnerComposite < HtmlGrid::Composite
	COMPONENTS = {
		[0,0]		=>	:substance,
		[2,0]		=>	:dose,
		[0,1]		=>	:chemical_substance,
		[2,1]		=>	:chemical_dose,
		[0,2]		=>	:equivalent_substance,
		[2,2]		=>	:equivalent_dose,
	}
	CSS_MAP = {
		[0,0,4,2]	=>	'list',
	}
	DEFAULT_CLASS = HtmlGrid::Value	
	LABELS = true
	def substance(model, session)
		model.substance.send(@lookandfeel.language)
	end
end
class ActiveAgentForm < View::Form
	include HtmlGrid::ErrorMessage
	COMPONENTS = {
		[0,0]		=>	:substance,
		[2,0]		=>	:dose,
		[4,0]		=>	:spagyric_dose,
		[0,1]		=>	:chemical_substance,
		[2,1]		=>	:chemical_dose,
		[0,2]		=>	:equivalent_substance,
		[2,2]		=>	:equivalent_dose,
		[1,3,0]	=>	:submit,
		[1,3,1]	=>	:delete_item,
		[1,4]		=>	:new_active_agent_button,
	}
	COMPONENT_CSS_MAP = {
		[0,0,8,3]	=>	'standard',
	}
	CSS_MAP = {
		[0,0,8,6]	=>	'list',
	}
	LABELS = true
	def init
		super
		error_message()
	end
	def new_active_agent_button(model, session)
		unless(@model.is_a? Persistence::CreateItem)
			post_event_button(:new_active_agent)
		end
	end
end
class ActiveAgentComposite < HtmlGrid::Composite
	COMPONENTS = {
		[0,0]	=>	:agent_name,
		[0,1]	=>	View::Admin::ActiveAgentInnerComposite,
	}
	CSS_CLASS = 'composite'
	CSS_MAP = {
		[0,0]	=>	'th',
	}
	def agent_name(model, session)
		sequence = model.parent(session.app)
		[sequence.name, model.pointer_descr].compact.join('&nbsp;-&nbsp;')	
	end
end
class RootActiveAgentComposite < View::Admin::ActiveAgentComposite
  include SwissmedicSource
	COMPONENTS = {
		[0,0]	=>	:agent_name,
		[0,1]	=>	View::Admin::ActiveAgentForm,
    [0,2] =>  :active_agents,
    [0,3] =>  'th_auxilliary',
    [0,4] =>  :auxilliary_substances,
    [0,5] =>  'th_source',
		[0,6]	=>	:source,
	}
	CSS_MAP = {
		[0,0]	=>	'th agent_name',
    [0,3] =>  'subheading th_auxilliary',
    [0,5] =>  'subheading th_source',
	}
  def initialize(model, session, is_active_agent = true)
    @is_active_agent = is_active_agent
    $stdout.puts "RootActiveAgentComposite.init @is_active_agent #{@is_active_agent}"
    super(model, session)
  end
  def active_agents(model, session=@session)
    agents = model.sequence.active_agents.find_all{|x| x.is_active_agent == @is_active_agent}
    $stdout.puts "RootActiveAgentComposite active_agents @is_active_agent #{@is_active_agent} #{model.sequence.active_agents.size} agents #{agents.size}"
    RootSequenceAgents.new(agents, @session, self)
  end
  def source(model, session=@session)
    val = HtmlGrid::Value.new(:source, model, @session, self)
    val.css_class = 'RootActiveAgentComposite-source'
    val.value = sequence_source(model.sequence) if model
    val
  end
end
class ActiveAgent < View::Drugs::PrivateTemplate
	CONTENT = View::Admin::ActiveAgentComposite
	SNAPBACK_EVENT = :result
  def initialize(agents, session, is_active_agent = true)
    $stdout.puts "RootActiveAgentComposite.init is_active_agent #{is_active_agent}"
    super(agents, session, is_active_agent)
  end
end
class RootActiveAgent < View::Admin::ActiveAgent
	CONTENT = View::Admin::RootActiveAgentComposite
end
		end
	end
end
