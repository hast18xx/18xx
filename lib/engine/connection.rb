# frozen_string_literal: true

module Engine
  class Connection
    attr_accessor :node_a, :node_b, :paths

    def self.layable_hexes(connections)
      hexes = Hash.new { |h, k| h[k] = [] }
      explored_connections = {}
      explored_paths = {}
      queue = []

      connections.each do |connection|
        puts "connection - #{connection.inspect}"
        queue << connection
      end

      while queue.any?
        connection = queue.pop
        explored_connections[connection] = true

        connection.paths.each do |path|
          next if explored_paths[path]

          explored_paths[path] = true
          hex = path.hex
          exits = path.exits
          puts "visit #{hex.inspect} #{exits}"
          hexes[hex] |= exits

          exits.each do |edge|
            neighbor = hex.neighbors[edge]
            edge = hex.invert(edge)
            next if neighbor.connections[edge].any?
            puts "coming to neighbor #{neighbor.inspect} #{edge}"
            hexes[neighbor] |= [edge]
          end
        end

        # why does this have l7 2
        connection.connections.each do |c|
          queue << c unless explored_connections[c]
        end
      end

      hexes.default = nil
      puts hexes

      hexes
    end

    def self.connect!(path)
      path.node ? connect_node!(path) : connect_edge!(path)
    end

    def self.connect_node!(path)
      puts "connecting node #{@coordinates} #{path.exits}"
      hex = path.hex
      node = path.node
      edge = path.exits[0]

      neighbor = hex.neighbors[edge]
      n_edge = hex.invert(edge)
      connections = neighbor.connections[n_edge]
      if connections.any?
        connections.each do |connection|
          connection.node_a ? connection.node_b = node : connection.node_a = node
          connection.paths << path
          hex.connections[edge] << connection
        end
        puts "adding connections from neighbors #{n_edge} #{hex.connections.inspect}"
      else
        connection = Connection.new(node, nil, [path])
        hex.connections[edge] << connection

        neighbor.tile.paths.each do |p|
          connect!(p) if p.exits.include?(n_edge)
        end
        puts "new connection #{edge} - #{n_edge} #{hex.connections.inspect}"
      end
    end

    def self.connect_edge!(path)
      puts "connecting edge #{@coordinates} #{path.exits} - #{path.hex&.name}"
      hex = path.hex
      edge_a, edge_b = path.exits

      connections_a = hex
        .neighbors[edge_a]
        .connections[hex.invert(edge_a)]
        .map { |c| c.extract_path!(path) }

      connections_b = hex
        .neighbors[edge_b]
        .connections[hex.invert(edge_b)]
        .map { |c| c.extract_path!(path) }

      merge(connections_a, connections_b).each do |connection|
        puts "** adding path #{path.hex.name} #{path.exits}"
        connection.paths << path

        connection.paths.each do |path|
          puts "** adding connection to hex #{path.hex.name} #{path.exits} #{connection.inspect}"
          path.exits.each do |edge|
            path.hex.connections[edge] << connection
          end
        end
      end
    end

    def self.merge(connections_a, connections_b)
      if connections_a.any? && connections_b.any?
        puts "both exists"
        connections_a.flat_map do |connection_a|
          connections_b.map do |connection_b|
            Connection.new(
              connection_a.node_a || connection_a.node_b,
              connection_b.node_a || connection_b.node_b,
              connection_a.paths | connection_b.paths,
            )
          end
        end
      elsif connections_a.any?
        connections_a
      elsif connections_b.any?
        connections_b
      else
        [Connection.new(nil, nil, [])]
      end
    end

    def initialize(node_a, node_b, paths)
      @node_a = node_a
      @node_b = node_b
      @paths = paths
    end

    def extract_path!(path)
      return branch(path) if hexes.include?(path.hex)

      @paths.each do |p|
        p.exits.each { |edge| p.hex.connections[edge].delete(self) }
      end

      self
    end

    def branch(path)
      hex_paths = @paths
        .reject { |p| p.hex == path.hex }
        .map { |p| [p.hex, p] }
        .to_h

      paths = {}
      queue = []
      queue << path

      while queue.any?
        p = queue.pop
        paths[p] = true
        neighbors = p.hex.neighbors

        p.exits.each do |edge|
          next unless (n_path = hex_paths[neighbors[edge]])

          queue << n_path unless paths[n_path]
        end
      end

      self.class.new(
        @node_a,
        @node_b,
        paths.keys - [path],
      )
    end

    def hexes
      @paths.map(&:hex)
    end

    def stops
      @paths.map(&:stop).uniq
    end

    def connections
      connections_for(@node_a) + connections_for(@node_b)
    end

    def connections_for(node)
      return [] unless node

      if node.offboard?
        return @paths.find { |p| p.node == node }.exits.flat_map do |edge|
          node.hex.connections[edge]
        end
      end

      node.hex.all_connections.select do |connection|
        connection.node_a == node || connection.node_b == node
      end
    end

    def tokened_by?(corporation)
      (@node_a&.city? && @node_a.tokened_by?(corporation)) ||
        (@node_b&.city? && @node_b.tokened_by?(corporation))
    end

    def inspect
      path_str = @paths.map(&:inspect).join(',')
      "<#{self.class.name}: node_a: #{@node_a&.hex&.name}, node_b: #{@node_b&.hex&.name}, paths: #{path_str}>"
    end
  end
end
