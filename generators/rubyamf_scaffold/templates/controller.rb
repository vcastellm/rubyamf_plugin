class <%= controller_class_name %>Controller < ApplicationController
  
  # return all <%= class_name.pluralize %>
  def find_all
    respond_to do |format|
      format.amf  { render :amf => <%= class_name %>.find(:all) }
    end
  end
  
  # return a single <%= class_name %> by id
  # expects id in params[0]
  def find_by_id
    respond_to do |format|
      format.amf { render :amf => <%= class_name %>.find(params[0]) }
    end
  end

  # saves new or updates existing <%= class_name %>
  # expect params[0] to be incoming <%= class_name %>
  def save
    respond_to do |format|
      format.amf do
        @<%= table_name.singularize %> = params[0]

        if @<%= table_name.singularize %>.save
          render :amf => @<%= table_name.singularize %>
        else
          render :amf => FaultObject.new(@<%= table_name.singularize %>.errors.full_messages.join('\n'))
        end
      end
    end
  end

  # destroy a <%= class_name %>
  # expects id in params[0]
  def destroy
    respond_to do |format|
      format.amf do
        @<%= table_name.singularize %> = <%= class_name %>.find(params[0])
        @<%= table_name.singularize %>.destroy

        render :amf => true
      end
    end
  end

end
