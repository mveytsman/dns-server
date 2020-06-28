defmodule DnsServer.Message do
  defstruct [:header, :answer, :authority, :additional, name_pointers: %{}, questions: []]

  defmodule Header do
    defstruct [
      :id,
      :qr,
      :opcode,
      :aa,
      :tc,
      :rd,
      :ra,
      :ad,
      :cd,
      :rcode,
      :qdcount,
      :ancount,
      :nscount,
      :arcount
    ]
  end

  defmodule Question do
    defstruct [:qname, :qtype, :qclass]
  end

  defmodule Parser do
    defstruct [:bytes, message: %DnsServer.Message{}, name_pointers: %{}, offset: 0]
  end

  def parse_message(bytes) do
    %Parser{bytes: bytes}
    |> parse_header()
    |> parse_questions()
  end

  @spec parse_header(DnsServer.Message.Parser.t()) :: DnsServer.Message.Parser.t()
  def parse_header(
        %Parser{
          message: message,
          bytes: <<
            # Request identifier
            id::16,
            # Query (0) or Response (1)
            qr::1,
            # 0 - Standard Query, 1 - Inverse Query, 2 - Server Status
            opcode::4,
            # Authoritative Answer
            aa::1,
            # TrunCation
            tc::1,
            # Recursion Desired
            rd::1,
            # Recursion Available
            ra::1,
            # Reserved
            _::1,
            # Authentic data
            ad::1,
            # Checking disabled
            cd::1,
            # Response code - 0 - No error, 1 - Format error, 2 - Server failure, 3 - Name error, 4 - Not implemented, 5 - Refused (policy reasons)
            rcode::4,
            # Count of entries in question section
            qdcount::16,
            # Count of resouce records in answer section
            ancount::16,
            # Count of name server resource records in answer section
            nscount::16,
            # Count of resources in the additonal records section
            arcount::16,
            # Rest of the message
            rst::bitstring
          >>,
          offset: offset
        } = parser
      ) do
    header = %Header{
      id: id,
      qr: qr,
      opcode: opcode,
      aa: aa,
      tc: tc,
      rd: rd,
      ra: ra,
      ad: ad,
      cd: cd,
      rcode: rcode,
      qdcount: qdcount,
      ancount: ancount,
      nscount: nscount,
      arcount: arcount
    }

    %{parser | message: %{message | header: header}, bytes: rst, offset: offset + 96}
  end

  # Recursively iterate qdcount times
  def parse_questions(%Parser{message: %{header: %{qdcount: num_questions}}} = parser),
    do: parse_questions(parser, num_questions)

  def parse_questions(%Parser{} = parser, 0), do: parser

  def parse_questions(%Parser{} = parser, num_questions) do
    {qname, parser} = parse_name(parser)
    <<qtype::16, qclass::16, bytes::bitstring>> = parser.bytes
    parser = parser
    |> Map.put(:bytes, bytes)
    |> Map.update!(:offset, &(&1+16))

    question = %Question{qname: qname, qtype: qtype, qclass: qclass}

    parser = update_in(parser.message.questions, &(&1 ++ [question]))
    parse_questions(parser, num_questions - 1)
  end

  def cache_name(%Parser{name_pointers: name_pointers} = parser, name, offset) do
    %{parser | name_pointers: Map.put(name_pointers, offset, name)}
  end

  def parse_name(%Parser{offset: offset} = parser), do: parse_name(parser, [], offset)

  def parse_name(
        %Parser{bytes: <<0::8, bytes::bitstring>>, offset: offset} = parser,
        labels,
        initial_offset
      ) do
    final_offset = offset + 8
    name = Enum.join(labels, ".")

    parser =
      %{parser | bytes: bytes, offset: final_offset}
      |> cache_name(name, initial_offset)

    {name, parser}
  end

  for label_length <- 1..63 do
    def parse_name(
          %Parser{
            bytes:
              <<0::2, unquote(label_length)::6, label::binary-size(unquote(label_length)),
                bytes::bitstring>>,
            offset: offset
          } = parser,
          labels,
          initial_offset
        ) do
      parser = %{parser | bytes: bytes, offset: offset + 8 + unquote(label_length)}
      parse_name(parser, labels ++ [label], initial_offset)
    end
  end

  defmodule Resouce do
    defstruct [:name, :type, :class, :ttl, :rdlength, :rdata]
  end
end
