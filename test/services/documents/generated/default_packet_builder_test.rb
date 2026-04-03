require "test_helper"

module Documents
  module Generated
    class DefaultPacketBuilderTest < ActiveSupport::TestCase
      class FakePlacementRelation
        attr_reader :calls

        def initialize
          @calls = []
        end

        def create!(attrs)
          @calls << attrs
          attrs
        end
      end

      class FakePacket
        attr_reader :title, :packet_placements

        def initialize(title)
          @title = title
          @packet_placements = FakePlacementRelation.new
        end
      end

      class FakeDocumentRelation
        attr_reader :created_packets

        def initialize(existing_titles: [])
          @existing_titles = existing_titles
          @created_packets = []
        end

        def generated
          self
        end

        def where(storage_uri:)
          self
        end

        def pluck(column)
          return @existing_titles if column.to_s == "title"

          []
        end

        def create!(attrs)
          packet = FakePacket.new(attrs[:title])
          @created_packets << [attrs, packet]
          packet
        end
      end

      test "creates only missing defaults and seeds shared canonical sources" do
        event = events(:one)
        built_by_user = users(:one)
        documents = FakeDocumentRelation.new(existing_titles: ["Pineapple Productions Packet"])
        canonical_keys = []
        canonical_source = Object.new
        page_source = Object.new
        page_saved = false

        canonical_source.define_singleton_method(:save!) { true }
        page_source.define_singleton_method(:save!) { page_saved = true }

        event.stub(:documents, documents) do
          GeneratedPacketSource.stub(:ensure_canonical_sources_for_event!, ->(_event) { true }) do
            GeneratedPacketSource.stub(:ensure_canonical!, ->(_event, key) { canonical_keys << key; canonical_source }) do
              GeneratedPacketSource.stub(:build_page_source, ->(**) { page_source }) do
                result = DefaultPacketBuilder.new(event: event, built_by_user: built_by_user).call

                assert_equal ["Family Packet"], result.map(&:title)
              end
            end
          end
        end

        assert_equal [GeneratedPacketSource::CANONICAL_KEYS[:event_overview],
                      GeneratedPacketSource::CANONICAL_KEYS[:planning_team],
                      GeneratedPacketSource::CANONICAL_KEYS[:family_timeline]], canonical_keys
        assert_equal 1, documents.created_packets.length

        attrs, packet = documents.created_packets.first
        assert_equal "Family Packet", attrs[:title]
        assert_equal Document::PACKET_SCHEMA_VERSIONS[:source_backed], attrs[:packet_schema_version]
        assert_equal 4, packet.packet_placements.calls.length
        assert page_saved
      end
    end
  end
end
