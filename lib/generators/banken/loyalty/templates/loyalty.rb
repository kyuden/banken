<% module_namespacing do -%>
class <%= class_name %>Loyalty < ApplicationLoyalty
  class Scope < Scope
    def resolve
      scope
    end
  end
end
<% end -%>
