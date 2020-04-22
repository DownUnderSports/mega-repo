Rails.application.reloader.after_class_unload do
  Rails.application.eager_load! if Rails.application.config.eager_load
end
