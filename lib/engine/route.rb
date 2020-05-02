# frozen_string_literal: true

require_relative 'game_error'

module Engine
  class Route
    attr_reader :connections, :phase, :train

    def initialize(phase, train)
      @connections = []
      @phase = phase
      @train = train
    end

    def reset!
      @hexes.clear
    end

    def add_connection(connection)
      puts "** adding connection #{connection}"
      #if (prev = @hexes.last) && !hex.connected?(prev)
      #  raise GameError, "Cannot use #{hex.name} in route because it is not connected"
      #end

      @connections << connection
      #return unless prev

      ## TODO @paths.concat(hex.connections(prev, direct: true))
    end

    def paths_for(paths)
      @connections.flat_map(&:paths) & paths
    end

    def stops
      @connections.flat_map(&:stop).uniq
    end

    def revenue
      stops_ = stops
      raise GameError, 'Route must have at least 2 stops' if stops_.size < 2
      raise GameError, "#{stops_.size} is too many stops for #{@train.distance} train" if @train.distance < stops_.size

      stops_.map { |stop| stop.route_revenue(@phase, @train) }.sum
    end
  end
end
