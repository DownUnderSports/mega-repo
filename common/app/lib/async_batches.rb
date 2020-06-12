module AsyncBatches
  def retrieve_batches_async(of: 2000, start: nil, finish: nil, preserve_order: false, &block)
    raise "No block given" unless block_given?

    relation = self
    relation = relation.reorder(batch_order) unless preserve_order
    relation = apply_limits(relation, start, finish)
    offset = 0
    batch_size = of || 1000

    records = nil
    while relation.limit(batch_size).offset(offset).exists?
      next_records = thread_exception = block_exception = nil
      thread = Thread.new(offset) {|t_offset|
        begin
          next_records = relation.limit(batch_size).offset(t_offset).to_a
        rescue => ex
          thread_exception = ex
        end
      }

      begin
        block.call records if records&.any?
      rescue => ex
        block_exception = ex
      ensure
        thread.join
      end

      if block_exception
        raise block_exception
      elsif thread_exception
        raise thread_exception
      end

      offset += batch_size
      records = next_records
      break if records.size < batch_size
    end
    block.call records if records&.any?
    nil
  end

  def retrieve_batch_values_async(**options)
    retrieve_batches_async options do |b|
      b.each do |v|
        yield v
      end
    end
  end
end
