# frozen_string_literal: true

# == Schema Information
#
# Table name: package_arrows
#
#  id                 :integer          not null, primary key
#  package_graph_id   :integer
#  from_id            :integer
#  to_id              :integer
#  x                  :decimal(9, 4)
#  y                  :decimal(9, 4)
#  width              :decimal(9, 4)
#  height             :decimal(9, 4)
#  text               :string(255)
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
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  percent_from_start :decimal(9, 4)
#

class PackageArrow < ApplicationRecord
  belongs_to :package_graph

  self.inheritance_column = nil

  def self.create_from(arrow, package_graph)
    package_arrow = PackageArrow.new(
      arrow.attributes.reject do |k, _|
        %w[id graph_id].include?(k)
      end
    ) do |e|
      e.package_graph = package_graph
    end
    package_arrow.save
    package_arrow
  end

  def self.create_arrow_from(package_arrow, graph)
    arrow = Arrow.new(
      package_arrow.attributes.reject do |k, _|
        %w[created_at updated_at id package_graph_id].include?(k)
      end
    ) do |e|
      e.graph = graph
    end
    arrow.save
    arrow
  end
end
