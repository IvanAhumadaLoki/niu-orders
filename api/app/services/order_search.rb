# Busca órdenes para el listado: aplica filtros, ordena y pagina.
#
# Parámetros aceptados (todos opcionales):
#   page             número de página, desde 1 (por defecto 1)
#   per_page         órdenes por página (por defecto 20, máximo 100)
#   dispatch_status  pending, sent o error
#   restaurant_id    ID del restaurante
#   order_type       pickup o delivery
#
# Uso:
#   result = OrderSearch.call(params)
#   result.success?  # => false si algún parámetro es inválido
#   result.orders    # => órdenes de la página, de la más reciente a la más antigua
#   result.meta      # => { page:, per_page:, total_count:, total_pages: }
#   result.errors    # => errores por parámetro, listos para devolver como 422
#
# Un `per_page` mayor al máximo se recorta (no es un error) y `meta` informa el
# valor realmente usado. Una página fuera de rango devuelve una lista vacía.
class OrderSearch
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  INVALID_INTEGER_MESSAGE = "debe ser un entero mayor que 0".freeze

  Result = Struct.new(:orders, :meta, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  def self.call(params)
    new(params).call
  end

  # `params` puede ser ActionController::Parameters ya permitido o un Hash.
  def initialize(params)
    @params = params.to_h.with_indifferent_access
  end

  def call
    errors = validation_errors
    return Result.new(orders: [], meta: nil, errors: errors) if errors.any?

    scope = filtered_scope
    total_count = scope.count

    # `includes` precarga restaurante e ítems: evita una consulta por orden al
    # armar el resumen. El desempate por `id` mantiene un orden estable entre
    # páginas aunque dos órdenes tengan exactamente la misma fecha.
    orders = scope.includes(:restaurant, :items)
                  .order(created_at: :desc, id: :desc)
                  .limit(per_page)
                  .offset((page - 1) * per_page)

    Result.new(
      orders: orders,
      meta: {
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      },
      errors: {}
    )
  end

  private

  def page
    @page ||= positive_integer(@params[:page]) || 1
  end

  def per_page
    @per_page ||= [ positive_integer(@params[:per_page]) || DEFAULT_PER_PAGE, MAX_PER_PAGE ].min
  end

  # Convierte a entero si el valor es un número positivo de hasta 9 dígitos;
  # si no, devuelve nil. El límite de dígitos evita desbordar el offset de la
  # consulta con números absurdamente grandes.
  def positive_integer(value)
    return nil unless value.to_s.match?(/\A\d{1,9}\z/)

    number = value.to_i
    number.positive? ? number : nil
  end

  def valid_integer?(value)
    value.blank? || !positive_integer(value).nil?
  end

  def filtered_scope
    scope = Order.all
    scope = scope.where(dispatch_status: @params[:dispatch_status]) if @params[:dispatch_status].present?
    scope = scope.where(order_type: @params[:order_type]) if @params[:order_type].present?
    scope = scope.where(restaurant_id: @params[:restaurant_id]) if @params[:restaurant_id].present?
    scope
  end

  def validation_errors
    errors = {}

    %i[page per_page restaurant_id].each do |name|
      errors[name] = [ INVALID_INTEGER_MESSAGE ] unless valid_integer?(@params[name])
    end

    status = @params[:dispatch_status]
    if status.present? && !Order.dispatch_statuses.key?(status)
      errors[:dispatch_status] = [ "debe ser uno de: #{Order.dispatch_statuses.keys.join(', ')}" ]
    end

    type = @params[:order_type]
    if type.present? && !Order.order_types.key?(type)
      errors[:order_type] = [ "debe ser uno de: #{Order.order_types.keys.join(', ')}" ]
    end

    errors
  end
end