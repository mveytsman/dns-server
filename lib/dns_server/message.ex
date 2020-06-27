defmodule DnsServer.Message do
  defstruct [:header, :question, :answer, :authority, :additional]

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

    def parse(<<
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
        >>) do
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

      {header, rst}
    end
  end

  defmodule Question do
    defstruct [:qname, :qtype, :qclass]
    def parse(message, num_questions), do: parse(message, num_questions, [])
    def parse(message, 0, questions), do: {questions, message}

    def parse(message, num_questions, questions) do
      {qname, message} = parse_qname(message)
      <<qtype::16, qclass::16, message::bitstring>> = message
      question = %Question{qname: qname, qtype: qtype, qclass: qclass}

      parse(message, num_questions - 1, questions ++ [question])
    end

    defp parse_qname(message), do: parse_qname(message, [])
    defp parse_qname(<<0::8, message::bitstring>>, labels), do: {Enum.join(labels, "."), message}

    for label_length <- 1..63 do
      defp parse_qname(
             <<0::2, unquote(label_length)::6, label::binary-size(unquote(label_length)),
               message::bitstring>>,
             labels
           ),
           do: parse_qname(message, labels ++ [label])
    end
  end

  def parse(message) do
    {header, message} = Header.parse(message)
    IO.inspect(header)
    {questions, message} = Question.parse(message, header.qdcount)
    IO.inspect(questions)
  end
end
