# encoding: UTF-8
# frozen_string_literal: true

class ApplicationController < Common::ApplicationController
  def fallback_index_html
    @disallow_ssr_render_caching  = true

    super
  end
end
