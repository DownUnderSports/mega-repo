module ValidatedAddresses
  def self.has_validated_address(
    model:,
    association_name: :address,
    state_association: :state,
    class_name: 'Address',
    foreign_key: :address_id,
    autosave: true,
    add_variants: false,
    inverse_options: {},
    skip_autosave_method: false,
    accept_nested_attributes: true,
    **opts
  )
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    model.belongs_to association_name,
      class_name: 'Address',
      foreign_key: foreign_key,
      autosave: autosave,
      **opts

    model.has_many :"#{association_name}_variations",
      through: association_name,
      class_name: 'Address::Variant' if add_variants

    model.has_one state_association, through: association_name if state_association

    model.accepts_nested_attributes_for association_name if accept_nested_attributes

    if opts[:inverse_of]
      should_touch = Boolean.parse(inverse_options.delete(:touch) || inverse_options.delete("touch"))

      Address.has_many opts[:inverse_of],
        inverse_of: association_name,
        autosave: autosave,
        **inverse_options

      if should_touch
        Address.define_method :"touch_#{opts[:inverse_of]}" do
          begin
            if __send__(opts[:inverse_of]).try(:minimum, :updated_at) > 5.seconds.ago
              __send__(opts[:inverse_of]).update_all(updated_at: Time.zone.now)
            end
          rescue
          end
          true
        end

        Address.after_commit :"touch_#{opts[:inverse_of]}"
      end
    end

    model.singleton_class.define_method :"#{association_name}_foreign_key" do
      @__created_address_association_fkey ||= indifferent_reflections[association_name].foreign_key
    end

    model.singleton_class.define_method :"#{association_name}_primary_key" do
      @__created_address_association_pkey ||= indifferent_reflections[association_name].options[:primary_key] || :id
    end

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    model.before_validation :"check_#{model.__send__ :"#{association_name}_foreign_key"}"
    # model.before_save :"autosave_associated_records_for_#{association_name}"

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

    # model.define_method :"autosave_associated_records_for_#{association_name}" do
    #   Address.autosave_belongs_to_model self, address
    #   true
    # end

    # model.define_method :"autosave_associated_records_for_#{association_name}" do
    #   tmp_address = __send__ association_name
    #
    #   unless tmp_address.present?
    #     tmp_address = nil
    #     return true
    #   end
    #
    #   if tmp_address.new_record?
    #     tmp_address = Address.merge_or_create(tmp_address)
    #   elsif existing = Address.find_by(id: tmp_address.id)
    #     if !tmp_address.allow_autosave_preserve?
    #       tmp_address = Address.merge_or_create(tmp_address.indifferent_attributes)
    #     end
    #   end
    #
    #   tmp_address.save
    #
    #   __send__ :"#{association_name}=", tmp_address
    #
    # end unless skip_autosave_method

    model.define_method :"#{association_name}_foreign_key" do
      self[self.class.__send__(:"#{association_name}_foreign_key")]
    end

    model.define_method :"#{association_name}_foreign_key=" do |value|
      write_attribute self.class.__send__(:"#{association_name}_foreign_key"), value
    end

    model.define_method :"#{association_name}_primary_key" do
      assc = __send__(association_name)
      assc[self.class.__send__(:"#{association_name}_primary_key")] if assc
    end

    model.define_method :"check_#{model.__send__ :"#{association_name}_foreign_key"}" do
      if self.__send__(:"#{association_name}_foreign_key") !=
        (tmp_new_val = __send__(:"#{association_name}_primary_key"))
        self.__send__(:"#{association_name}_foreign_key=", tmp_new_val)
      end
      true
    end

    model.define_method :"autosave_associated_records_for_#{association_name}" do
      Address.run_autosave_belongs_to_model(self, __send__(association_name), association_name)
    end unless skip_autosave_method
  end

  has_validated_address model: Address::Variant,
    inverse_of: :variants,
    inverse_options: { class_name: 'Address::Variant', dependent: :destroy }

  has_validated_address model: Flight::Airport,
    inverse_of: :flight_airports,
    optional: true,
    inverse_options: { class_name: 'Flight::Airport', dependent: :nullify, touch: true }

  has_validated_address model: School,
    inverse_of: :schools,
    inverse_options: { dependent: :nullify, touch: true }

  has_validated_address model: Traveler::Hotel,
    inverse_of: :traveler_hotels,
    inverse_options: { class_name: 'Traveler::Hotel', dependent: :nullify, touch: true }

  has_validated_address model: User,
    inverse_of: :users,
    optional: true,
    inverse_options: { dependent: :nullify, touch: true }
end
