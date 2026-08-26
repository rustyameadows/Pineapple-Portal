require "combine_pdf"
require "grover"

module Documents
  module Generated
    class PageNumberOverlayRenderer
      GROVER_OPTIONS = {
        prefer_css_page_size: true,
        margin: { top: "0", bottom: "0", left: "0", right: "0" },
        print_background: true,
        omit_background: true,
        timeout: 30_000
      }.freeze

      def initialize(page_label:, page_width_points:, page_height_points:, page_text_color: "#000000")
        @page_label = page_label
        @page_width_points = page_width_points
        @page_height_points = page_height_points
        @page_text_color = page_text_color
      end

      def call
        pdf = Grover.new(render_html, **GROVER_OPTIONS).to_pdf
        CombinePDF.parse(pdf).pages.first
      end

      private

      attr_reader :page_label, :page_width_points, :page_height_points, :page_text_color

      def render_html
        ApplicationController.render(
          template: "generated_documents/page_number_overlay",
          layout: false,
          assigns: {
            page_label: page_label,
            page_width_points: page_width_points,
            page_height_points: page_height_points,
            page_text_color: page_text_color
          }
        )
      end
    end
  end
end
