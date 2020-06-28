defmodule DnsServer.Message do


  # TODO:
  # Try with ERL_COMPILER_OPTIONS=bin_opt_info
  # See https://tech.forzafootball.com/blog/binary-parsing-optimizations-in-elixir

  defstruct [
    :header,
    questions: [],
    answers: [],
    authority: [],
    additional: []
  ]

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

  defmodule ResouceRecord do
    defstruct [:name, :type, :class, :ttl, :rdlength, :rdata]
  end

  defmodule Parser do
    defstruct [:bytes, message: %DnsServer.Message{}, name_pointers: %{}, offset: 0]
  end

  def parse_message(bytes) do
    %Parser{bytes: bytes}
    |> parse_header()
    |> parse_questions()
    |> parse_answers()
    |> parse_authority()
    |> parse_additional()
  end

  @spec parse_header(DnsServer.Message.Parser.t()) :: DnsServer.Message.Parser.t()
  def parse_header(
        %Parser{
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

    # Put the parsed header value into the message, in the parser
    parser = put_in(parser.message.header, header)

    # Make sure to update the bytes and the offset
    %{parser | bytes: rst, offset: offset + 96}
  end

  # Recursively iterate qdcount times
  def parse_questions(%Parser{message: %{header: %{qdcount: num_questions}}} = parser),
    do: parse_questions(parser, num_questions)

  def parse_questions(%Parser{} = parser, 0), do: parser

  def parse_questions(%Parser{} = parser, num_questions) do
    {qname, parser} = parse_name(parser)
    <<qtype::16, qclass::16, bytes::bitstring>> = parser.bytes

    parser =
      parser
      |> Map.put(:bytes, bytes)
      |> Map.update!(:offset, &(&1 + 16))

    question = %Question{qname: qname, qtype: qtype, qclass: qclass}

    parser = update_in(parser.message.questions, &(&1 ++ [question]))
    parse_questions(parser, num_questions - 1)
  end

  # TODO broken
  @spec cache_name(DnsServer.Message.Parser.t(), any, any) :: DnsServer.Message.Parser.t()
  def cache_name(%Parser{name_pointers: name_pointers} = parser, name, offset) do
    %{parser | name_pointers: Map.put(name_pointers, offset, name)}
  end

  def get_name(%Parser{name_pointers: name_pointers}, offset) do
    unless Map.has_key?(name_pointers, offset) do
      raise "key not found"
    end

    name_pointers[offset]
  end

  def parse_name(%Parser{offset: offset} = parser), do: parse_name(parser, [], offset)

  # End of name
  def parse_name(
        %Parser{bytes: <<0::8, rst::bitstring>>, offset: offset} = parser,
        labels,
        initial_offset
      ) do
    final_offset = offset + 8
    name = Enum.join(labels, ".")

    parser =
      %{parser | bytes: rst, offset: final_offset}
      |> cache_name(name, initial_offset)

    {name, parser}
  end

  # Pointer
  def parse_name(
        %Parser{
          bytes: <<3::2, ptr::6, rst::bitstring>>,
          offset: offset
        } = parser,
        labels,
        initial_offset
      ) do
    final_offset = offset + 8
    labels = labels ++ get_name(parser, ptr)
    name = Enum.join(labels, ".")

    parser =
      %{parser | bytes: rst, offset: final_offset}
      |> cache_name(name, initial_offset)

    {name, parser}
  end

  # Label piece
  def parse_name(
        %Parser{
          bytes: <<0::2, len::6, label::binary-size(len), bytes::bitstring>>,
          offset: offset
        } = parser,
        labels,
        initial_offset
      ) do
    parser = %{parser | bytes: bytes, offset: offset + 8 + len * 8}
    parse_name(parser, labels ++ [label], initial_offset)
  end

  def parse_answers(%Parser{message: %{header: %{ancount: num_answers}}} = parser),
    do: parse_answers(parser, num_answers)

  def parse_answers(%Parser{} = parser, 0), do: parser

  def parse_answers(%Parser{} = parser, num_answers) do
    {resouce_record, parser} = parse_resource_record(parser)
    parser = update_in(parser.message.answers, &(&1 ++ [resouce_record]))
    parse_answers(parser, num_answers - 1)
  end

  def parse_authority(%Parser{message: %{header: %{nscount: num_authority}}} = parser),
    do: parse_authority(parser, num_authority)

  def parse_authority(%Parser{} = parser, 0), do: parser

  def parse_authority(%Parser{} = parser, num_authority) do
    {resouce_record, parser} = parse_resource_record(parser)
    parser = update_in(parser.message.authority, &(&1 ++ [resouce_record]))
    parse_authority(parser, num_authority - 1)
  end

  def parse_additional(%Parser{message: %{header: %{arcount: num_additional}}} = parser),
    do: parse_additional(parser, num_additional)

  def parse_additional(%Parser{} = parser, 0), do: parser

  def parse_additional(%Parser{} = parser, num_additional) do
    {resouce_record, parser} = parse_resource_record(parser)
    parser = update_in(parser.message.additional, &(&1 ++ [resouce_record]))
    parse_additional(parser, num_additional - 1)
  end

  def parse_resource_record(parser) do
    {name, parser} = parse_name(parser)
    <<type::16, class::16, ttl::32, rdlength::16, rdata::binary-size(rdlength), bytes::bitstring>> = parser.bytes
    record = %ResouceRecord{name: name, type: type, class: class, ttl: ttl, rdlength: rdlength, rdata: rdata}
    {record, %{parser | bytes: bytes, offset: parser.offset + 80 + rdlength }}
  end
end
