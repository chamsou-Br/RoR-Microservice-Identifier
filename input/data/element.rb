# frozen_string_literal: true

# == Schema Information
#
# Table name: elements
#
#  id                :integer          not null, primary key
#  graph_id          :integer
#  type              :string(255)
#  model_id          :integer
#  x                 :decimal(9, 4)
#  y                 :decimal(9, 4)
#  width             :decimal(9, 4)
#  height            :decimal(9, 4)
#  text              :text(65535)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  shape             :string(255)
#  parent_role       :integer
#  parent_id         :integer
#  comment           :text(65535)
#  leasher_id        :integer
#  font_size         :integer
#  color             :string(255)
#  indicator         :string(255)
#  zindex            :integer
#  titlePosition     :string(255)      default("middle")
#  bold              :boolean          default(FALSE)
#  italic            :boolean          default(FALSE)
#  underline         :boolean          default(FALSE)
#  corner_radius     :integer
#  title_color       :string(255)
#  title_fontfamily  :string(255)
#  model_type        :string(255)
#  logo              :boolean          default(FALSE)
#  main_process      :boolean          default(FALSE)
#  graph_image_id    :integer
#  raw_comment       :text(16777215)
#  comment_color     :string(255)      default("#6F78B9")
#  indicator_comment :text(65535)
#
# Indexes
#
#  index_elements_on_graph_id     (graph_id)
#  index_elements_on_leasher_id   (leasher_id)
#  index_elements_on_model_id     (model_id)
#  index_elements_on_model_type   (model_type)
#  index_elements_on_parent_id    (parent_id)
#  index_elements_on_parent_role  (parent_role)
#  index_elements_on_type         (type)
#  index_elements_on_zindex       (zindex)
#
class Element < ApplicationRecord
  belongs_to :graph
  belongs_to :graph_image, optional: true

  has_one :arrow_out, class_name: "Arrow", foreign_key: :from_id
  has_one :arrow_in, class_name: "Arrow", foreign_key: :to_id
  has_one :lane
  has_many :pastilles, dependent: :destroy

  validates :x, :y, :width, :height, presence: true

  validates :type, inclusion: { in: %w[lane border_lane intern extern
                                       unit instruction sub-procedure
                                       graphup graphdownstream graphstart
                                       graphend processus-group processus
                                       subprocessus procedure
                                       collaborative-instruction resource
                                       and or document recording
                                       sticker operation control-operation
                                       corrective-operation sequential
                                       alternative image] }

  validates :shape, inclusion: { in: %w[lane role instruction graphup
                                        graphdownstream graphstart graphend
                                        processus collaborative-instruction
                                        resource relatedRole logical-operator
                                        document recording sticker
                                        operation control-operation
                                        corrective-operation macroinstruction
                                        macrooperation image] }

  validates :indicator, inclusion: { in: [nil, "none", "time", "money",
                                          "quantity", "quality", "environment",
                                          "hygiene", "security", "regulation",
                                          "corrective"] }

  validates :text, uniqueness: { scope: %i[graph_id shape],
                                 unless: :allow_duplicate_text?,
                                 if: :is_role? }

  scope :commented, -> { where(" comment IS NOT NULL ") }

  # @!attribute parent_role
  #   @return [ID]

  self.inheritance_column = nil

  def as_json(_options = {})
    super(include: :pastilles)
  end

  # rubocop:disable Naming/PredicateName
  # TODO: Rename `is_role?` to `role?`
  def is_role?
    shape == "role"
  end

  # TODO: Rename `is_linked?` to `linked?`
  def is_linked?
    !(model_id.nil? || model_type.nil?)
  end
  # rubocop:enable Naming/PredicateName

  # rubocop:disable Naming/AccessorMethodName
  # TODO: Rename `get_leasher_elmnt` to `leasher_element`
  def get_leasher_elmnt
    return nil if leasher_id.nil?

    Element.find_by_id(leasher_id)
  end

  # TODO: Rename `get_leashed_elmnt` to `leashed_element`
  def get_leashed_elmnt
    Element.find_by_leasher_id(id)
  end

  # TODO: Rename `get_linked_entity` to `linked_entity`
  def get_linked_entity
    # TODO: use polymorphic association
    return nil unless is_linked?

    model_type.constantize.send :find, model_id
  end

  # TODO: Rename `get_arrows_attached_below` to `arrows_attached_below`
  def get_arrows_attached_below
    arrows_below = Arrow.where(from_id: id)
    res = []
    arrows_below.each do |arrow|
      if (arrow.hidden == true) && (arrow.to.shape == "logical-operator")
        res += Arrow.where(from_id: arrow.to_id).to_a
      else
        res << arrow
      end
    end
    res
  end

  # TODO: Rename `get_arrows_attached_above` to `arrows_attached_above`
  def get_arrows_attached_above
    arrows_above = Arrow.where(to_id: id)
    res = []
    arrows_above.each do |arrow|
      if (arrow.hidden == true) && (arrow.from.shape == "logical-operator")
        res += Arrow.where(to_id: arrow.from_id).to_a
      else
        res << arrow
      end
    end
    res
  end
  # rubocop:enable Naming/AccessorMethodName

  # TODO: Refactor `self.duplicate_for` into smaller methods for each record
  # type.  Consider externalizing into module
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def self.duplicate_for(graph_duplicated, graph_template = nil)
    ids_mapping = []
    graph_template = graph_duplicated.parent if graph_template.nil?
    graph_template.elements.each do |element|
      old_id = element.id
      element_duplicated = element.dup
      element_duplicated.graph = graph_duplicated
      element_duplicated.save
      new_id = element_duplicated.id
      ids_mapping << { old_id: old_id, new_id: new_id }
    end
    # Mapping des nouveaux ids
    graph_duplicated.elements.each do |element_duplicated|
      ids_mapping.each do |id_mapping|
        if element_duplicated.parent_id == id_mapping[:old_id]
          element_duplicated.parent_id = id_mapping[:new_id]
        elsif element_duplicated.leasher_id == id_mapping[:old_id]
          element_duplicated.leasher_id = id_mapping[:new_id]
        elsif element_duplicated.parent_role == id_mapping[:old_id]
          element_duplicated.parent_role = id_mapping[:new_id]
        end
      end
      element_duplicated.save
    end
    # Duplication des pastilles
    graph_template.elements.each do |element|
      element.pastilles.each do |pastille|
        pastille_duplicated = pastille.dup
        ids_mapping.each do |id_mapping|
          if pastille_duplicated.element_id == id_mapping[:old_id]
            pastille_duplicated.element_id = id_mapping[:new_id]
          elsif pastille_duplicated.role_id == id_mapping[:old_id]
            pastille_duplicated.role_id = id_mapping[:new_id]
          end
        end
        pastille_duplicated.save
      end
    end
    # Duplication des lanes
    graph_template.lanes.each do |lane|
      lane_duplicated = lane.dup
      lane_duplicated.graph = graph_duplicated
      ids_mapping.each do |id_mapping|
        lane_duplicated.element_id = id_mapping[:new_id] if lane_duplicated.element_id == id_mapping[:old_id]
      end
      lane_duplicated.save
    end
    # Duplication des arrows
    graph_template.arrows.each do |arrow|
      arrow_duplicated = arrow.dup
      arrow_duplicated.graph = graph_duplicated
      ids_mapping.each do |id_mapping|
        if arrow_duplicated.from_id == id_mapping[:old_id]
          arrow_duplicated.from_id = id_mapping[:new_id]
        elsif arrow_duplicated.to_id == id_mapping[:old_id]
          arrow_duplicated.to_id = id_mapping[:new_id]
        end
      end
      arrow_duplicated.save
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # TODO: Remove `self.shapes_linkable_to_graph` in favor of class constant
  def self.shapes_linkable_to_graph
    %w[instruction graphup graphdownstream processus
       collaborative-instruction operation]
  end

  # TODO: Remove `self.actions_shapes_linkable_to_graph` in favor of class
  # constant
  def self.actions_shapes_linkable_to_graph
    # Utiliser pour mettre en place les requêtes des graphes parents/fils. Les
    # liaisons graphup/graphdownstream ne sont pas compris
    # <---1P---><-----------------2P------------------><---3P--->
    %w[processus instruction collaborative-instruction operation]
  end

  def self_and_descendants
    graph.elements.where(parent_id: id).reduce([self]) do |res, son|
      res + son.self_and_descendants
    end
  end

  private

  def allow_duplicate_text?
    shape == "lane" || graph&.level == 1
  end
end
