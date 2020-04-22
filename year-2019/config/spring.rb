Spring::Watcher::Listen.class_eval do
  def base_directories
    %w[
        app
        config
        lib/db
        lib/handlers
        lib/modules
        spec
        ../common
      ].
        uniq.
        map    { |path| Pathname.new(File.join(root, path)) }.
        select { |path| File.directory?(path) }
  end
end

%w[
  .ruby-version
  .rbenv-vars
  tmp/restart.txt
  tmp/caching-dev.txt
].
  each { |path| Spring.watch(path) }
