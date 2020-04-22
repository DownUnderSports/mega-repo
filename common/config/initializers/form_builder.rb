class FormBuilder < ActionView::Helpers::FormBuilder
  def id_for(method, options={})
    InstanceTag.new(object_name, method, self, options).id_for( options )
  end
end

class InstanceTag < ActionView::Helpers::Tags::Base
  def id_for( options )
    add_default_name_and_id(options)
    options['id']
  end
end

ActionView::Base.default_form_builder = FormBuilder 
