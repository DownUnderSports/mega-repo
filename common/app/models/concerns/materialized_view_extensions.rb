module MaterializedViewExtensions
  def self.included(klass, *args)
    class << klass
      alias :super_all :all

      def batch_updates
        !!@batch_updates
      end

      def batch_updates=(value)
        @batch_updates = !!value
      end

      prepend PrependClassMethods
    end
    prepend PrependMethods
  end

  module PrependClassMethods
    def reload
      !batch_updates && ViewTracker.refresh_view(self.table_name)
    end

    def live_reload(with_lock = false)
      ViewTracker.refresh_view(self.table_name, async: false, concurrently: !with_lock)
    end

    def live_reload_and_query(*args)
      live_reload(*args)
      self
    end

    def last_refresh
      ViewTracker.last_refresh(self.table_name)
    end

    def reload_when
      return super if defined?(super)
      !batch_updates && !(last_refresh &.> 5.minutes.ago)
    end

    def all
      reload_when && self.reload
      super
    end
  end

  module PrependMethods
    def parent_class
      defined?(super) ? super : nil
    end

    def instance_primary_key
      defined?(super) ? super : id
    end

    def update(*args, **opts)
      update!(*args, **opts)
    rescue
      false
    end

    def update!(*args, **opts)
      res = parent_class.find(instance_primary_key).update!(*args, **opts)
      self.class.reload
      res
    end
  end
end
