# encoding: utf-8
# frozen_string_literal: true

<% module_namespacing do -%>
require 'rails_helper'

RSpec.describe <%= class_name %>, <%= type_metatag(:model) %> do
  has_valid_factory(:<%= class_name.constantize.table_name.singularize %>)

  describe 'Attributes' do
    # run `rails spec:attributes <%= class_name -%>` to replace this line

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
<% end -%>
