class Result
  attr_reader :value, :errors

  def self.success(value:)
    new(success: true, value: value, errors: [])
  end

  def self.failure(errors:)
    new(success: false, value: nil, errors: errors)
  end

  def initialize(success:, value:, errors:)
    @success = success
    @value = value
    @errors = Array(errors).compact
  end

  def success?
    @success
  end
end
