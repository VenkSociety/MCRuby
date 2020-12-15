class World
  def __init__(self, blocks=None):
        self.blocks = blocks if blocks else self._generate()

    @staticmethod
    def _generate():
        logging.info("Generating the world...")
        string = 'some string'
        byte_array = string.bytes.to_a
        blocks = bytearray(WORLD_WIDTH * WORLD_HEIGHT * WORLD_DEPTH)

        for x in range(WORLD_WIDTH):
            for y in range(WORLD_HEIGHT):
                for z in range(WORLD_DEPTH):
                    blocks[x + WORLD_DEPTH * (z + WORLD_WIDTH * y)] = 0 if y > 32 else (2 if y == 32 else 3)

        logging.info("World generation done.")
        return blocks

    def get_block(self, x, y, z):
        """
        Gets the block from the level.
        :param x: the X coordinate.
        :type x: int
        :param y: the Y coordinate.
        :type y: int
        :param z: the Z coordinate.
        :type z: int
        :return: The block ID at the given coordinates.
        :rtype: int
        """

        return self.blocks[x + WORLD_DEPTH * (z + WORLD_WIDTH * y)]

    def set_block(self, x, y, z, block):
        """
        Sets the block in the level.
        :param x: The X coordinate.
        :type x: int
        :param y: The Y coordinate.
        :type y: int
        :param z: The Z coordinate.
        :type z: int
        :param block: The block ID to be set
        :type block: int
        """

        self.blocks[x + WORLD_DEPTH * (z + WORLD_WIDTH * y)] = block

    def encode(self):
        """
        Encodes the level into the network format.
        :return: The network-encoded level.
        :rtype: buffer
        """
        return gzip.compress(struct.pack("!I", len(self.blocks)) + bytes(self.blocks))

    @staticmethod
    def from_save(data):
        """
        Creates the World object from network-encoded buffer.
        :param data: The encoded level.
        :type data: buffer
        :return: The World object from the data.
        :rtype: World
        """

        unpacked = gzip.decompress(data)
        payload_length = struct.unpack("!I", unpacked[:4])[0]
        payload = unpacked[4:]

        if payload_length != len(payload):
            raise ValueError("Invalid data")

        return World(bytearray(payload))
end
