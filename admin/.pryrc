og_print = Pry.config.print

Pry.config.print = proc do |output, value, *args|
  begin
    if (ActiveRecord::Base === value) ||
      (ActiveRecord::Relation === value)
      is_relation = ActiveRecord::Relation === value
      base = (is_relation ? value.limit(1).first : value)
      i = 0
      idx = {'   #' => ->(*args) { "   #{i += 1}" }}
      keys = [
        idx, *(
          (
            base ? (
              (
                (base.class.first).present? &&
                (base.class.first.attributes.keys - base.attributes.keys).present?
              ) ?
              base.attributes.keys :
              (base.class.respond_to?(:default_print) ? base.class.default_print : base.class.column_names)
            ) : (value.klass.respond_to?(:default_print) ? value.klass.default_print : value.klass.column_names)
          )
        )
      ]
      puts "\n"
      if is_relation
        sz = 0
        begin
          tp value, keys if value.size > 0
          sz = value.size
        rescue
          tp value, keys if value.size.size > 0
          sz = value.size.size
        end
        puts "\n   #{sz} rows returned" if is_relation
      else
        tp value, keys
      end
      puts "\n"
    else
      og_print.call output, value, *args
    end
  rescue
    og_print.call output, value, *args
  end
end
