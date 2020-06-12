ActiveSupport.on_load(:active_record) do
  module ActiveRecord
    module Batches
      include AsyncBatches
    end

    class Relation
      include AsyncBatches
    end

    module Querying
      delegate  :retrieve_batches_async,
                :retrieve_batch_values_async,
                to: :all
    end
  end
end
