# frozen_string_literal: true

# == Schema Information
#
# Table name: arrows
#
#  id                 :integer          not null, primary key
#  graph_id           :integer
#  from_id            :integer
#  to_id              :integer
#  x                  :decimal(9, 4)
#  y                  :decimal(9, 4)
#  width              :decimal(9, 4)
#  height             :decimal(9, 4)
#  text               :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  type               :string(255)
#  hidden             :boolean          default(FALSE)
#  comment            :text(65535)
#  attachment         :string(255)
#  sx                 :decimal(9, 4)
#  sy                 :decimal(9, 4)
#  ex                 :decimal(9, 4)
#  ey                 :decimal(9, 4)
#  font_size          :integer
#  color              :string(255)
#  grip_in            :string(255)
#  grip_out           :string(255)
#  centered           :boolean          default(TRUE)
#  title_color        :string(255)
#  title_fontfamily   :string(255)
#  stroke_color       :string(255)
#  stroke_width       :integer
#  raw_comment        :text(16777215)
#  comment_color      :string(255)      default("#6F78B9")
#  percent_from_start :decimal(9, 4)
#
# Indexes
#
#  index_arrows_on_from_id   (from_id)
#  index_arrows_on_graph_id  (graph_id)
#  index_arrows_on_to_id     (to_id)
#

#
# An **arrow** in process modeling is used to describe a connection between 2
# {Element}s.
#
class Arrow < ApplicationRecord
  # @!attribute [rw] graph
  #   @return [Graph]
  belongs_to :graph

  # @!attribute [rw] from
  #   @return [Element]
  belongs_to :from, class_name: "Element", foreign_key: "from_id"

  # @!attribute [rw] to
  #   @return [Element]
  belongs_to :to, class_name: "Element", foreign_key: "to_id"

  # @!attribute [rw] height
  #   @return [BigDecimal]
  # @!attribute [rw] width
  #   @return [BigDecimal]
  validates :width, :height, presence: true

  # @!attribute [rw] attachment
  #   @return [String, nil]
  validates :attachment, inclusion: { in: %w[none up down] }

  # @!attribute [rw] text
  #   @return [String, nil]
  validates :text, length: { maximum: 255 }, allow_nil: true

  # @!attribute [rw] type
  #   @return [String, nil]
  validates :type, inclusion: { in: %w[straight rectangular loop-left loop-right pentagon] }

  self.inheritance_column = nil

  scope :commented, -> { where(" comment IS NOT NULL ") }

  after_initialize :set_default_attachment

  def self.delete_ids_not_in(js_arrows)
    available_ids = js_arrows.collect { |js_arrow| js_arrow["id"] }
    available_ids.delete_if { |id| id.nil? || id.is_a?(String) }
    if available_ids.empty?
      delete_all
    else
      where("id NOT IN (?)", available_ids).delete_all
    end
  end

  # TODO: Refactor `self.create_or_update_from_json` into 2 smaller methods
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.create_or_update_from_json(js_arrow)
    if js_arrow["id"].is_a?(Numeric)
      arrow = find_or_create_by(id: js_arrow["id"])
      arrow.update_attributes(
        "x" => js_arrow["x"],
        "y" => js_arrow["y"],
        "percent_from_start" => js_arrow["percent_from_start"],
        "width" => js_arrow["width"],
        "height" => js_arrow["height"],
        "from_id" => js_arrow["from"],
        "to_id" => js_arrow["to"],
        "text" => js_arrow["text"],
        "type" => js_arrow["type"],
        "hidden" => js_arrow["hidden"],
        "centered" => js_arrow["centered"],
        "attachment" => js_arrow["attachment"],
        "comment" => js_arrow["comment"],
        "comment_color" => js_arrow["comment_color"],
        "raw_comment" => js_arrow["raw_comment"],
        "font_size" => js_arrow["font_size"],
        "color" => js_arrow["color"],
        "title_color" => js_arrow["title_color"],
        "title_fontfamily" => js_arrow["title_fontfamily"],
        "sx" => js_arrow["sx"],
        "sy" => js_arrow["sy"],
        "ex" => js_arrow["ex"],
        "ey" => js_arrow["ey"],
        "grip_in" => js_arrow["grip_in"],
        "grip_out" => js_arrow["grip_out"],
        "stroke_width" => js_arrow["stroke_width"],
        "stroke_color" => js_arrow["stroke_color"]
      )
      arrow
    else
      js_arrow.delete_if { |key, _value| key == "id" }
      create do |a|
        a.x = js_arrow["x"]
        a.y = js_arrow["y"]
        a.percent_from_start = js_arrow["percentFromStart"]
        a.width = js_arrow["width"]
        a.height = js_arrow["height"]
        a.from_id = js_arrow["from"]
        a.to_id = js_arrow["to"]
        a.text = js_arrow["text"]
        a.type = js_arrow["type"]
        a.hidden = js_arrow["hidden"]
        a.centered = js_arrow["centered"]
        a.attachment = js_arrow["attachment"]
        a.comment = js_arrow["comment"]
        a.comment_color = js_arrow["comment_color"]
        a.raw_comment = js_arrow["raw_comment"]
        a.font_size = js_arrow["font_size"]
        a.color = js_arrow["color"]
        a.title_color = js_arrow["title_color"]
        a.title_fontfamily = js_arrow["title_fontfamily"]
        a.sx = js_arrow["sx"]
        a.sy = js_arrow["sy"]
        a.ex = js_arrow["ex"]
        a.ey = js_arrow["ey"]
        a.grip_in = js_arrow["grip_in"]
        a.grip_out = js_arrow["grip_out"]
        a.stroke_width = js_arrow["stroke_width"]
        a.stroke_color = js_arrow["stroke_color"]
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def set_default_attachment
    self.attachment ||= "none"
  end
end
