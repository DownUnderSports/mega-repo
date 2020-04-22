module DashedRoutes
  def self.extended(router)
    router.instance_exec do
      unless defined?(og_resources)
        alias :og_resources :resources
        def resources(*args, **opts, &block)
          v = og_resources *args, **opts, &block
          catch(:skip) do
            throw :skip unless opts[:dashed]

            str = args.first.to_s
            hyp = str.gsub('_', '-')

            throw :skip if str == hyp

            opts[:path] = hyp
            catch(:run) do
              throw(:run) if opts[:dashed] == :all
              allowed = %i[ index show ]
              opts[:only] = [*opts[:only]].presence || allowed
              opts[:only].filter! {|value| allowed.include?(value)  }

              throw :skip unless opts[:only].present?
            end


            og_resources *args, **opts.except(:dashed), &block
          end

          v
        end

        alias :og_namespace :namespace
        def namespace(*args, **opts, &block)
          v = og_namespace *args, **opts, &block
          catch(:skip) do
            throw :skip unless opts[:dashed]
            str = args.first.to_s
            hyp = str.gsub('_', '-')
            unless str == hyp
              og_namespace str, path: hyp, &block
            end
          end
          v
        end

        alias :og_get :get
        def get(*args, **opts, &block)
          v = og_get *args, **opts, &block
          if args.first.is_a?(Symbol) && (args.size == 1) && opts.blank?
            str = args.first.to_s
            hyp = str.gsub('_', '-')
            unless str == hyp
              og_get str, as: hyp
            end
          end
          v
        end
      end
    end
  end
end
