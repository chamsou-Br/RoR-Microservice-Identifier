# frozen_string_literal: true

module GroupsHelper
  def groups_labels_for_js(groups)
    res = "["
    i = 0
    groups.each do |group|
      i += 1
      res += "\"#{group.title}\""
      res += "," unless i >= groups.size
    end
    res += "]"
    res.html_safe
  end
end
