#!/usr/bin/env ruby
# encoding: utf-8
# ODDB::View::Drugs::Prescription -- oddb.org -- 28.08.2012 -- yasaka@ywesee.com
# before commit 83d798fb133f10008dd95f2b73ebc3e11c118b16 of 2014-10-14 we had a view which 
# allowed entering a lot of details (before, during, after meals, repetitions, etc)
# Test it with http://oddb-ci2.dyndns.org/de/gcc/rezept/ean/7680317061142,7680353520153,7680546420673,7680193950301,7680517950680
#
# The javascript function (js_<x>) are found under doc/resources/javascript/prescription.js

require 'csv'
require 'cgi'
require 'htmlentities'
require 'htmlgrid/errormessage'
require 'htmlgrid/infomessage'
require 'htmlgrid/select'
require 'htmlgrid/textarea'
require 'htmlgrid/inputtext'
require 'htmlgrid/inputcheckbox'
require 'htmlgrid/inputradio'
require 'htmlgrid/component'
require 'view/drugs/privatetemplate'
require 'view/drugs/centeredsearchform'
require 'view/interactions/interaction_chooser'
require 'view/additional_information'
require 'view/searchbar'
require 'view/printtemplate'
require 'view/publictemplate'
require 'view/form'
require 'view/zsr'
require 'util/zsr'

module ODDB
  module View
    module Drugs
class PrescriptionInteractionDrugDiv < HtmlGrid::Div
  def init
    super
    @value = []
    @drugs = @session.choosen_drugs
    if @drugs and !@drugs.empty?
      @value << View::Interactions::InteractionChooserDrug.new(@model, @session, self)
    end
  end
end

class PrescriptionDrugHeader < HtmlGrid::Composite
  include View::AdditionalInformation
  COMPONENTS = {
    [0,0] => :fachinfo,
    [1,0] => :drug,
    [2,0] => :delete,
  }
  CSS_MAP = {
    [0,0] => 'small',
    [1,0] => '',
    [2,0] => 'small',
  }
  def init
    @drugs = @session.choosen_drugs
    if @model and @model.barcode and @model.barcode.length == 13
      @index = @drugs.keys.index(@model.barcode)
    else
      @index = 0
    end
    super
  end
  def fachinfo(model, session=@session)
    if fi = super(model, session, 'square bold infos')
      fi.set_attribute('target', '_blank')
      fi
    end
  end
  def drug(model, session=@session)
    div = HtmlGrid::Div.new(model, @session, self)
    div.value = []
    if model
      div.value << '&nbsp;'
      div.value <<  model.name_with_size
      if price = model.price_public
        div.value << '&nbsp;-&nbsp;'
        div.value << price.to_s
      end
      if company = model.company_name
        div.value << '&nbsp;-&nbsp;'
        div.value << company
        div.value << '&nbsp;'
      end
    end
    div
  end
  def delete(model, session=@session)
    if (@drugs and @drugs.length >= 1) #and model.barcode != drugs.first.barcode)
      link = HtmlGrid::Link.new(:minus, model, session, self)
      link.set_attribute('title', @lookandfeel.lookup(:delete))
      link.css_class = 'delete square'
      link.set_attribute('id', "delete_#{@index}") # to allow correct deleting in watir tests
      args = [:ean, model.barcode] if model
      url = @session.request_path.sub(/(,|)#{model.barcode.to_s}/, '').sub(/\?$/, '')
      link.onclick = "require(['dojo/domReady!'], function(){ js_delete_ean_of_index('#{url}', #{@index} ); });"
      link
    end
  end
end
class PrescriptionDrugMoreArea < HtmlGrid::Div # replace target
  def init
    super
    if @model
      div = HtmlGrid::Div.new(@model, @session, self)
      div.set_attribute('id', 'drugs')
      @value = div
    end
  end
end
class PrescriptionDrug < HtmlGrid::Composite
  COMPONENTS = {
    [0,0] => :drug,
		[0,1] => :interactions,
    [0,2] => :prescription_comment,
		[0,4] => :atc_code,
  }
  CSS_MAP = {
    [0,0] => 'subheading',
    [0,1] => 'list',
    [0,2] => 'top',
  }
  COMPONENT_CSS_MAP = {
    [0,2] => 'wide',
  }
  CSS_CLASS = 'composite'
  def init
    @drugs = @session.choosen_drugs
    @index = -1
    if @model and @drugs and !@drugs.empty?
      @index = @drugs.keys.index(@model.barcode)
    end
    if @index and @drugs and !@drugs.empty?
      @model = @drugs.values[@index]
    end
    @attributes.store('id', 'drugs_' + @model.barcode) if @attributes and @model
    super
  end
  def interactions(model, session)
    View::Drugs::PrescriptionInteractionDrugDiv.new(model, session, self)
  end

  def atc_code(model,session)
    # this is needed by js for external link to modules.epha.ch
    hidden = HtmlGrid::Input.new(:atc_code, model, session, self)
    hidden.set_attribute('type', 'hidden')
    if model and model.atc_class and code = model.atc_class.code
      hidden.value = code
    end
    hidden
  end
  def drug(model, session)
    View::Drugs::PrescriptionDrugHeader.new(model, session, self)
  end
  def prescription_comment(model, session)
    name = "prescription_comment_#{@index}".intern
    textarea = HtmlGrid::Textarea.new(name.intern, model, @session, self)
    Helpers.saveFieldValueForLaterUse(textarea, name, @lookandfeel.lookup(:prescription_comment))
    textarea
  end
end
class PrescriptionDrugDiv < HtmlGrid::Div
  def init
    @drugs = @session.choosen_drugs
    super # must come first or it will overwrite @value
    @value = []
    if @drugs and !@drugs.empty?
      @drugs.each{ |ean, drug|
        @value << PrescriptionDrug.new(drug, @session, self)
      }
    end
  end
  def to_html(context)
    html = super
    html << View::Drugs::PrescriptionDrugMoreArea.new(@model, @session, self).to_html(context)
    html
  end
end
class PrescriptionDrugSearchForm < HtmlGrid::Composite # see View::Drugs::CenteredComperSearchForm
  attr_reader :index_name
  EVENT = :compare
  FORM_METHOD = 'POST'
  COMPONENTS = {
    [0,0] => :searchbar,
  }
  SYMBOL_MAP = {
    :searchbar => View::PrescriptionDrugSearchBar,
  }
  def init
    super
    self.onload = %(require(["dojo/domReady!"], function(){ document.getElementById('searchbar').focus(); });)
    @index_name = 'oddb_package_name_with_size_company_name_and_ean13'
    @additional_javascripts = []
  end
  def javascripts(context)
    scripts = ''
    @additional_javascripts.each do |script|
      args = {
        'type'     => 'text/javascript',
        'language' => 'JavaScript',
      }
      scripts << context.script(args) do script end
    end
    scripts
  end
  def to_html(context)
    javascripts(context).to_s << super
  end
end
class PrescriptionForm < View::Form
  include HtmlGrid::InfoMessage
  CSS_CLASS = 'composite'
  DEFAULT_CLASS = HtmlGrid::Value
  LABELS = true
  def prescription_for(model, session)
    fields = []
    fields << @lookandfeel.lookup(:prescription_for)
    fields << '&nbsp;&nbsp;&nbsp;'
    %w[first_name family_name birth_day].each do |attr|
      key = "prescription_#{attr}".to_sym
			value = @lookandfeel.lookup(key)
      fields << @lookandfeel.lookup(key)
      fields << '&nbsp;'
      input = HtmlGrid::InputText.new(key, model, session, self)
      input.set_attribute('size', 13)
      input.label = false
      Helpers.saveFieldValueForLaterUse(input, key, '')
      fields << input
      fields << '&nbsp;&nbsp;'
    end
    fields << @lookandfeel.lookup(:prescription_sex)
    fields << '&nbsp;'
    radio = HtmlGrid::InputRadio.new(:prescription_sex, model, session, self)
    Helpers.saveFieldValueForLaterUse(radio, :prescription_sex, 1)
    radio.value = '1'
    radio.set_attribute('checked', true)
    fields << radio
    fields << '&nbsp;'
    fields << @lookandfeel.lookup(:prescription_sex_w)
    fields << '&nbsp;'
    radio = HtmlGrid::InputRadio.new(:prescription_sex, model, session, self)
    Helpers.saveFieldValueForLaterUse(radio, :prescription_sex, 2)
    radio.value = '2'
    fields << radio
    fields << '&nbsp;'
    fields << @lookandfeel.lookup(:prescription_sex_m)
    fields
  end
  def hidden_fields(context)
    hidden = super
    # main drug
    hidden << context.hidden('ean', @model.barcode) if @model and @model.respond_to?(:barcode)
    hidden << context.hidden('prescription', true)
    hidden
  end
  def prescription_zsr_id(model, session)
    fields = []
    fields << @lookandfeel.lookup(:zsr_id)
    fields << '&nbsp;'
    input = HtmlGrid::InputText.new(:prescription_zsr_id, model, session, self)
    input.set_attribute('size', 10)
    input.label = false
    zsr_id = @session.zsr_id
    input.value = zsr_id
    Helpers.saveFieldValueForLaterUse(input, :prescription_zsr_id, '')
    url = @session.create_search_url(:rezept)
    js =  "require(['dojo/domReady!'], function(){ js_goto_url_with_zsr('#{url}');});"
    input.onclick = js
    input.set_attribute('onload', js)
    input.set_attribute('onBlur', js)
    input.set_attribute('onchange', js)
    fields << input
    fields
  end  
  def buttons(model, session)
    buttons = []
    print = post_event_button(:print)
    drugs = @session.choosen_drugs
    zsr_id = @session.zsr_id
    elements = zsr_id ? [ :rezept, ('zsr_'+zsr_id).to_sym ] : [ :rezept]
    elements += [:ean, drugs.keys].flatten
    new_url = @lookandfeel._event_url(:print, elements)
    print.onclick = "window.open('#{new_url}');"

    buttons << print
    buttons << '&nbsp;'
    @drugs = @session.choosen_drugs
    @session.set_persistent_user_input(:export_drugs, @drugs)
    buttons << post_event_button(:export_csv)
    buttons << '&nbsp;'
    buttons
  end
  def delete_all(model, session=@session)
    @drugs = @session.choosen_drugs
    delete_all_link = HtmlGrid::Link.new(:delete, @model, @session, self)
    delete_all_link.href  = @lookandfeel._event_url(:rezept, [:ean] )
    delete_all_link.value = @lookandfeel.lookup(:interaction_chooser_delete_all)
    delete_all_link.onclick = "require(['dojo/domReady!'], function(){ js_clear_session_storage();});"
    delete_all_link
  end
  private 
  def init
    first_idx  = [0,6]
    second_idx = [0,10]
    @components = {
      [0,0]  => :prescription_for,
      [0,1]  => View::Drugs::PrescriptionDrugDiv,
      [0,2]  => View::Drugs::PrescriptionDrugSearchForm,
      [0,4]  => :prescription_zsr_id,
      [0,13,0] => :buttons,
      [0,13,1] => :delete_all,
      [0,14] => 'prescription_notes',
    }
    @css_map = {
      [0,0]  => 'th bold',
      [0,1]  => '',
      [0,2]  => '',
      [0,4]  => 'bold',
      [0,13,0] => 'button',
      [0,13,1] => 'button',
      [0,14] => 'bold',
    }
    @colspan_map = {
      [0,0]  => 3,
      [0,1]  => 3,
      [0,2]  => 3,
      [0,4]  => 3,
      [0,13,0] => 3,
      [0,13,1] => 3,
      [0,15] => 3,
    }
    if @session.zsr_id
      @components[first_idx]   = 'prescription_signature'
      @components[second_idx ] = View::ZsrDetails
      @css_map[first_idx]      = 'bold'
      @css_map[second_idx]     = ''
      @colspan_map[first_idx]  = 3
      @colspan_map[second_idx] = 3
    else
      @components[first_idx]  =  'prescription_signature'
      @css_map[first_idx]     = 'bold'
      @colspan_map[first_idx] = 3
    end
    super
    @form_properties.update({
      'id'     => 'prescription_form',
      'target' => '_blank'
    })
    url = @session.create_search_url(:rezept)
  self.onload = "
  require(['dojo/domReady!'], function(){
    console.log('prescription_form_init.onload\\n url: #{url}\\nhref ' + window.location.href + '\\n top ' + window.top.location.href);
    js_goto_url_with_zsr('#{url}');
    prescription_form_init('#{@lookandfeel.lookup(:prescription_comment)}');
});
"
  end
end
class PrescriptionComposite < HtmlGrid::Composite
  include AdditionalInformation
  COMPONENTS = {
    [0,0] => View::Drugs::PrescriptionForm,
  }
  COMPONENT_CSS_MAP = {
    [0,0] => 'composite',
  }
  COLSPAN_MAP = {
    [0,0] => 12,
  }
  CSS_CLASS = 'composite'
  DEFAULT_CLASS = HtmlGrid::Value
end
class PrescriptionPrintInnerComposite < HtmlGrid::Composite
  COMPONENTS = {
    [0,1] => :name,
    [0,2] => :interactions,
    [0,3] => :prescription_comment,
    [0,4] => :comment_value,
    [0,5] => :ean13,
  }
  CSS_MAP = {
    [0,1] => 'print bold',
    [0,3] => 'print bold italic',
    [0,4] => 'print',
  }
  CSS_CLASS = 'compose'
  DEFAULT_CLASS = HtmlGrid::Value
  def init
    @drugs = @session.choosen_drugs
    @index = nil
    if @model and @drugs and !@drugs.empty?
      @index = @drugs.keys.index(@model.barcode)
    end
    if @index and @drugs and !@drugs.empty?
      @model = @drugs.values[@index]
    end
    @prescription_comment = @lookandfeel.lookup(:prescription_comment)
    @attributes.store('id', 'print_drugs_' + @model.barcode) if @attributes and @model
    super
  end
  def interactions(model, session)
    View::Drugs::PrescriptionInteractionDrugDiv.new(model, session, self)
  end

  def name(model, session=@session)
    span = HtmlGrid::Span.new(model, session, self)
    span.value = ''
    return span unless model
    span.value << model.name_with_size
    if price = model.price_public
      span.value << '&nbsp;-&nbsp;'
      span.value << price.to_s
    end
    if model.respond_to?(:company_name) and company = model.company_name
      span.value << '&nbsp;-&nbsp;'
      span.value << company
    end
    span.set_attribute('class', 'bold')
    span
  end
  def prescription_comment(model, session=@session)
    field_id = "prescription_header_#{@index}"
    span = HtmlGrid::Span.new(model, session, self)
    span.set_attribute('id', field_id)
    span.value = @prescription_comment
    span
  end
  def comment_value(model, session=@session)
    field_id = "prescription_comment_#{@index}"
    span = HtmlGrid::Span.new(model, session, self)
    span.set_attribute('id', field_id)
    span
  end
  def ean13(model, session=@session)
    span = HtmlGrid::Span.new(model, session, self)
    span.set_attribute('id', "prescription_ean13_#{@index}")
    span.set_attribute('style', "display:none")
    span.value =  @model.barcode if @model and @model.respond_to?(:barcode)
    span
  end
end
class PrescriptionPrintComposite < HtmlGrid::DivComposite
  include PrintComposite
  include View::AdditionalInformation
  PRINT_TYPE = ""
  COMPONENTS = {
    [0,0] => :epha_public_domain,
    [0,1] => '&nbsp;',
    [0,2] => :qr_code_image,
    [0,3] => :print_type,
    [0,4] => '&nbsp;',
    [0,5] => :prescription_for,
    [0,6] => '&nbsp;',
    [0,7] => :prescription_title,
    [0,8] => :document,
    [0,9] => '&nbsp;',
    [0,10] => :prescription_signature,
    [0,11] => '<BR><BR><BR><BR>', # four empty lines for the signature
    [0,12] => View::ZsrDetails,
  }
  CSS_MAP = {
    [0,0] => 'print-type',
    [0,1] => 'print',
    [0,2] => 'print',
    [0,3] => 'print-type',
    [0,4] => 'print',
    [0,5] => 'print',
    [0,6] => 'print',
    [0,7] => 'print',
    [0,8] => 'print',
    [0,1] => 'print',
    [0,10] => 'bold',
    [0,11] => 'print',
    [0,12] => 'print',
  }
  def init
    @drugs = @session.choosen_drugs
    super
self.onload = %(require(["dojo/domReady!"], function(){
  print_composite_init('#{@lookandfeel.lookup(:prescription_comment)}');
  add_prescription_qr_code(null, 'qr_code_image');
  });
  )

  end
  def epha_public_domain(model, session=@session)
    desc = @lookandfeel.lookup(:interaction_chooser_description) + ' ' + @lookandfeel.lookup(:epha_public_domain)
    span = HtmlGrid::Span.new(model, session, self)
    span.value = desc
    span.set_attribute('rowspan', '15')
    span
  end
  def qr_code_image(model, session=@session)
    image = HtmlGrid::Div.new(model, session, self)
    image.set_attribute('id', 'qr_code_image')
    image.set_attribute('colspan', '15')
    image
  end
  def prescription_for(model, session=@session)
    fields = []
    fields << @lookandfeel.lookup(:prescription_for)
    fields << '&nbsp;&nbsp;&nbsp;'
    %w[first_name family_name birth_day].each do |attr|
      key = "prescription_#{attr}".to_sym
      value = @lookandfeel.lookup(key)
      fields << @lookandfeel.lookup(key)
      fields << '&nbsp;'
      span = HtmlGrid::Span.new(model, session, self)
      span.set_attribute('class', 'bold')
      span.set_attribute('id', key)
      fields << span
      fields << '&nbsp;&nbsp;'
    end
    span = HtmlGrid::Span.new(model, session, self)
    type = (@session.user_input(:prescription_sex) == '1' ? 'w' : 'm')
    span.set_attribute('id', :prescription_sex)
    span.set_attribute('class', 'bold')
    fields << span
    fields
  end
  def prescription_signature(model, session=@session)
    span = HtmlGrid::Span.new(model, session=@session)
    span.value = @lookandfeel.lookup(:prescription_signature)
    span.set_attribute('class', 'bold')
    span
  end
  def prescription_title(model, session=@session)
    "#{@lookandfeel.lookup(:date)}:&nbsp;#{Date.today.strftime("%d.%m.%Y")}"
  end
  def document(model, session=@session)
    fields = []
    @drugs.each do |key, pack|
      composite = View::Drugs::PrescriptionPrintInnerComposite.new(pack, session, self)
      fields << composite
    end if @drugs
    fields
  end
end
class PrescriptionPrint < View:: PrintTemplate
  CONTENT = View::Drugs::PrescriptionPrintComposite
  JAVASCRIPTS = ['qrcode', 'prescription']
  def init
    @drugs = @session.choosen_drugs
    @index = (@drugs ? @drugs.length : 0).to_s
    if @model and @drugs and !@drugs.empty?
      @index = @drugs.keys.index(@model.barcode).to_s
    end
    super
  end
  def head(model, session=@session)
    span = HtmlGrid::Span.new(model, session, self)
    drugs = @session.choosen_drugs
    span.value = @lookandfeel.lookup(:print_of) +
      @lookandfeel._event_url(:print, [:rezept, :ean, drugs  ? drugs.keys : [] ].flatten)
    span
  end
end
class Prescription < View::PrivateTemplate
  CONTENT = View::Drugs::PrescriptionComposite
  SNAPBACK_EVENT = :result
  JAVASCRIPTS = ['admin', 'prescription']
  def init
    super
  end
  def backtracking(model, session=@session)
    fields = []
    fields << @lookandfeel.lookup(:th_pointer_descr)
    link = HtmlGrid::Link.new(:result, model, @session, self)
    link.css_class = "list"
    query = @session.persistent_user_input(:search_query)
    if query and !query.is_a?(SBSM::InvalidDataError)
      args = [
        :zone, :drugs, :search_query, query.gsub('/', '%2F'), :search_type,
        @session.persistent_user_input(:search_type) || 'st_oddb',
      ]
      link.href = @lookandfeel._event_url(:search, args)
      link.value = @lookandfeel.lookup(:result)
    end
    fields << link
    fields << '&nbsp;-&nbsp;'
    title = @lookandfeel.lookup(:prescription_title)
    span = HtmlGrid::Span.new(model, session, self)
    span.value = "#{title}:&nbsp;#{Date.today.strftime("%d.%m.%Y")}"
    span.set_attribute('class', 'bold')
    fields << span
    fields
  end
end
class PrescriptionCsv < HtmlGrid::Component
  COMPONENTS = [ # of package
    :barcode,
    :name_with_size,
    :price_public,
    :company_name,
  ]
  def init
    super
    @coder = HTMLEntities.new
  end
  def http_headers
    prescription_for = []
    %w[first_name family_name birth_day].each do |attr|
      prescription_for << user_input(attr)
    end
    name = @lookandfeel.lookup(:prescription).dup + '_'
    name ||= '_'
    unless prescription_for.empty?
      name << prescription_for.join('_').gsub(/[\s]+/u, '_')
    else
      name << Date.today.strftime("%d.%m.%Y")
    end
    {
      'Content-Type'        => 'text/csv',
      'Content-Disposition' => "attachment;filename=#{name}.csv",
    }
  end
  def to_csv
    @lines = []
    @lines << person
    insert_blank
    @lines << date
    insert_blank
    drugs = @session.persistent_user_input(:export_drugs)
    @index = 0
    drugs.each do |ean13, package|
      @lines << extract(package)
      insert_blank
      if comment = comment_value
        insert_blank
        @lines << comment
      end
      insert_blank
      @index += 1
    end
    @lines.pop
    csv = ''
    @lines.collect do |line|
      csv << CSV.generate_line(line, {:col_sep => ';'})
    end
    csv
  end
  def to_html(context)
    to_csv
  end
  private
  def user_input(attr)
    key = "prescription_#{attr}".to_sym
    input = @session.user_input(key)
    case input
    when String
      # pass
    when Hash
       if element = input[@index] and !element.empty?
         input = element
       else
         input = nil
       end
    else
      input = nil
    end
    input = @coder.decode(input).gsub(/;/, ' ') if input.class == String
    input
  end
  def lookup(attr)
    key = "prescription_#{attr}".to_sym
    if value = @lookandfeel.lookup(key)
      @coder.decode(value)
    end
  end
  def insert_blank
    if !@lines.last or !@lines.last.empty?
      @lines << []
    end
  end
  # line
  def person
    type = (user_input(:sex) == '1' ? 'w' : 'm')
    [
      user_input(:first_name)  || '',
      user_input(:family_name) || '',
      user_input(:birth_day)   || '',
      lookup("sex_#{type}")
    ]
  end
  def date
    [Date.today.strftime("%d.%m.%Y")]
  end
  def extract(pack)
    COMPONENTS.collect do |key|
      value = if(self.respond_to?(key))
        self.send(key, pack)
      elsif pack
        pack.send(key)
      else
        ""
      end.to_s
      value.empty? ? nil : value
    end
  end
  def comment_value
    comment = user_input(:comment)
    comment ? [comment] : []
  end
end
    end
  end
end
