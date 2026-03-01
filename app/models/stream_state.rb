class StreamState < ApplicationRecord
  def self.singleton!
    first_or_create!(live: false)
  end
end
