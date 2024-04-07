# frozen_string_literal: true

# == Schema Information
#
# Table name: package_elements
#
#  id                :integer          not null, primary key
#  package_graph_id  :integer
#  type              :string(255)
#  model_id          :integer
#  x                 :decimal(9, 4)
#  y                 :decimal(9, 4)
#  width             :decimal(9, 4)
#  height            :decimal(9, 4)
#  text              :text(65535)
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
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  indicator_comment :text(65535)
#

# TODO: Refactor `PackageElement` into smaller included module as it seems to
# copy behavior from other element records
class PackageElement < ApplicationRecord
  belongs_to :package_graph

  has_many :pastilles, dependent: :destroy, class_name: "PackagePastille", foreign_key: "element_id"

  self.inheritance_column = nil

  def self.create_from(element, package_graph)
    package_element = PackageElement.new(
      element.attributes.reject do |k, _|
        %w[id graph_id].include?(k)
      end
    ) do |e|
      e.package_graph = package_graph
    end
    package_element.save
    package_element
  end

  # TODO: Refactor `self.copy_elements_from_to` into 5 smaller private methods,
  # 1 for each element type
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def self.copy_elements_from_to(graph, package_graph)
    ids_mapping = []
    graph.elements.each do |element|
      old_id = element.id
      package_element = create_from(element, package_graph)
      new_id = package_element.id
      ids_mapping << { old_id: old_id, new_id: new_id }
    end
    # Mapping des nouveaux ids
    package_graph.elements.each do |element|
      ids_mapping.each do |id_mapping|
        if element.parent_id == id_mapping[:old_id]
          element.parent_id = id_mapping[:new_id]
        elsif element.leasher_id == id_mapping[:old_id]
          element.leasher_id = id_mapping[:new_id]
        elsif element.parent_role == id_mapping[:old_id]
          element.parent_role = id_mapping[:new_id]
        end
      end
      element.save
    end
    # Duplication des pastilles
    graph.elements.each do |element|
      element.pastilles.each do |pastille|
        package_pastille = PackagePastille.create_from(pastille)
        ids_mapping.each do |id_mapping|
          if package_pastille.element_id == id_mapping[:old_id]
            package_pastille.element_id = id_mapping[:new_id]
          elsif package_pastille.role_id == id_mapping[:old_id]
            package_pastille.role_id = id_mapping[:new_id]
          end
        end
        package_pastille.save
      end
    end
    # Duplication des lanes
    graph.lanes.each do |lane|
      package_lane = PackageLane.create_from(lane, package_graph)
      ids_mapping.each do |id_mapping|
        package_lane.element_id = id_mapping[:new_id] if package_lane.element_id == id_mapping[:old_id]
      end
      package_lane.save
    end
    # Duplication des arrows
    graph.arrows.each do |arrow|
      package_arrow = PackageArrow.create_from(arrow, package_graph)
      ids_mapping.each do |id_mapping|
        if package_arrow.from_id == id_mapping[:old_id]
          package_arrow.from_id = id_mapping[:new_id]
        elsif package_arrow.to_id == id_mapping[:old_id]
          package_arrow.to_id = id_mapping[:new_id]
        end
      end
      package_arrow.save
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def self.create_element_from(package_element, graph)
    element = Element.new(
      package_element.attributes.reject do |k, _|
        %w[created_at updated_at id package_graph_id].include?(k)
      end
    ) do |e|
      e.graph = graph
    end
    element.save
    element
  end

  # TODO: Refactor `self.copy_package_element_from_to` into 5 private methods
  # for each element type copying
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def self.copy_package_elements_from_to(package_graph, graph)
    ids_mapping = []

    package_graph.elements.each do |package_element|
      old_id = package_element.id
      element = create_element_from(package_element, graph)
      new_id = element.id
      ids_mapping << { old_id: old_id, new_id: new_id }
    end

    # Mapping des nouveaux ids
    graph.elements.each do |element|
      ids_mapping.each do |id_mapping|
        if element.parent_id == id_mapping[:old_id]
          element.parent_id = id_mapping[:new_id]
        elsif element.leasher_id == id_mapping[:old_id]
          element.leasher_id = id_mapping[:new_id]
        elsif element.parent_role == id_mapping[:old_id]
          element.parent_role = id_mapping[:new_id]
        end
      end
      element.save
    end

    # Duplication des pastilles
    package_graph.elements.each do |package_element|
      package_element.pastilles.each do |package_pastille|
        pastille = PackagePastille.create_pastille_from(package_pastille, graph)
        ids_mapping.each do |id_mapping|
          if pastille.element_id == id_mapping[:old_id]
            pastille.element_id = id_mapping[:new_id]
          elsif pastille.role_id == id_mapping[:old_id]
            pastille.role_id = id_mapping[:new_id]
          end
        end
        pastille.save
      end
    end

    # Duplication des lanes
    package_graph.lanes.each do |package_lane|
      lane = PackageLane.create_lane_from(package_lane, graph)
      ids_mapping.each do |id_mapping|
        lane.element_id = id_mapping[:new_id] if lane.element_id == id_mapping[:old_id]
      end
      lane.save
    end

    # Duplication des arrows
    package_graph.arrows.each do |package_arrow|
      arrow = PackageArrow.create_arrow_from(package_arrow, graph)
      ids_mapping.each do |id_mapping|
        if arrow.from_id == id_mapping[:old_id]
          arrow.from_id = id_mapping[:new_id]
        elsif arrow.to_id == id_mapping[:old_id]
          arrow.to_id = id_mapping[:new_id]
        end
      end
      arrow.save
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # TODO: Rename `is_role?` to `role?`
  # rubocop:disable Naming/PredicateName
  def is_role?
    shape == "role"
  end
  # rubocop:enable Naming/PredicateName
end
