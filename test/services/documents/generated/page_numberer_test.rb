require "test_helper"

module Documents
  module Generated
    class PageNumbererTest < ActiveSupport::TestCase
      class OverlayRendererStub
        class << self
          attr_accessor :calls
        end

        def initialize(page_label:, page_width_points:, page_height_points:, page_text_color:)
          self.class.calls ||= []
          self.class.calls << {
            page_label: page_label,
            page_width_points: page_width_points,
            page_height_points: page_height_points,
            page_text_color: page_text_color
          }
          @page_width_points = page_width_points
          @page_height_points = page_height_points
        end

        def call
          CombinePDF.create_page([0, 0, @page_width_points, @page_height_points])
        end
      end

      setup do
        OverlayRendererStub.calls = []
      end

      test "packet without a cover starts numbering at Pg. 1" do
        pdf_data = build_pdf([[612, 792], [612, 792]])
        entries = [
          entry(page_count: 2, view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY)
        ]

        result = PageNumberer.new(
          pdf_data: pdf_data,
          entries: entries,
          overlay_renderer: OverlayRendererStub
        ).call

        assert_equal ["Pg. 1", "Pg. 2"], OverlayRendererStub.calls.map { |call| call[:page_label] }
        assert_equal 2, CombinePDF.parse(result).pages.count
      end

      test "cover pages are skipped visually but still counted" do
        pdf_data = build_pdf([[612, 792], [612, 792], [612, 792]])
        entries = [
          entry(page_count: 1, view_key: "cover_sheet"),
          entry(page_count: 2, view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY)
        ]

        PageNumberer.new(
          pdf_data: pdf_data,
          entries: entries,
          overlay_renderer: OverlayRendererStub
        ).call

        assert_equal ["Pg. 2", "Pg. 3"], OverlayRendererStub.calls.map { |call| call[:page_label] }
      end

      test "multi-page segments continue numbering across entry boundaries" do
        pdf_data = build_pdf([[612, 792], [612, 792], [612, 792], [612, 792]])
        entries = [
          entry(page_count: 1, view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY),
          entry(page_count: 3, view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY)
        ]

        PageNumberer.new(
          pdf_data: pdf_data,
          entries: entries,
          overlay_renderer: OverlayRendererStub
        ).call

        assert_equal ["Pg. 1", "Pg. 2", "Pg. 3", "Pg. 4"], OverlayRendererStub.calls.map { |call| call[:page_label] }
      end

      test "page sizes are passed through to the overlay renderer" do
        pdf_data = build_pdf([[595, 842]])
        entries = [
          entry(page_count: 1, view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY)
        ]

        PageNumberer.new(
          pdf_data: pdf_data,
          entries: entries,
          overlay_renderer: OverlayRendererStub
        ).call

        assert_equal 595.0, OverlayRendererStub.calls.last[:page_width_points]
        assert_equal 842.0, OverlayRendererStub.calls.last[:page_height_points]
        assert_equal "#000000", OverlayRendererStub.calls.last[:page_text_color]
      end

      test "section break pages use a white page number" do
        pdf_data = build_pdf([[612, 792]])
        entries = [
          entry(page_count: 1, view_key: "section_break")
        ]

        PageNumberer.new(
          pdf_data: pdf_data,
          entries: entries,
          overlay_renderer: OverlayRendererStub
        ).call

        assert_equal "#ffffff", OverlayRendererStub.calls.last[:page_text_color]
      end

      private

      def build_pdf(page_sizes)
        pdf = CombinePDF.new
        page_sizes.each do |(width, height)|
          pdf << CombinePDF.create_page([0, 0, width, height])
        end
        pdf.to_pdf
      end

      def entry(page_count:, view_key:)
        {
          page_count: page_count,
          source: Struct.new(:cached_page_count, :html_view_key).new(page_count, view_key)
        }
      end
    end
  end
end
