---
marp: true
theme: default
_class: lead
paginate: true
backgroundColor: #fff
---

# I think i found a bug in Elixir!!
## (sort of maybe not really)
### Max Veytsman

---

# Elixir looks like ruby

But it has (non exhaustive list!)
- Erlang "magic"
- Pattern matching
- "Bitstrings"

---

# This is a bitstring

```elixir
<<...>>
```

---

# It can represent a sequence of bytes

```elixir
<<72, 101, 108, 108, 111>>
```

--- 

# In fact, these bytes are printable

```elixir
iex> <<72, 101, 108, 108,111>>
"Hello"
```
---

# It doesn't need to be bytes (hence bitstring not bytestring)

Here's `010` written in binary
```elixir
<< 0::1, 1::1, 0::1>>
```

---

# Types & Sizes

```elixir
iex> << 0::1, 1::1, 0::1>>
<<2::size(3)>>
```

- `::` specifies the type and size of the segment
- `1::8` is the same as `1::size(8)` is the same as `1::integer-size(8)`
---

# Types & Sizes

```elixir
iex> <<2::3>>
<<2::size(3)>>

iex> << 0::1, 1::1, 0::1>> == <<2::3>>
true
```

---

# Patern Matching

Assign variables values matched in bit strings

```elixir
 <<x::8, rst::bitstring>> = "Hello World"

iex> x
72

iex> rst
"ello World"
```

--- 


# Patern Matching

This is where specifying type is wonderful

```elixir
 <<c::bitstring-size(8), rst::bitstring>> = "Hello World"

iex>c
"H"

iex> rst
"ello World"
```

---

# Pattern matching
Also works in functions

```elixir
def parse_header(<<id::16, qr::1, opcode::4, ...>>) do
    make_header(id, qr, opcode...)
end
```

--- 

# My actual header parser

```elixir
 def parse_header(
    <<
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
```

---


# But what about labels

```elixir
iex> <<0::2, len::6, label::len, rst::bitstring>> = bytes
** (CompileError) iex:25: unknown bitstring specifier: len()
```

---

# So I decided to write a macro...

```elixir
for label_length <- 1..63 do
  defp parse_label(
     <<0::2, unquote(label_length)::6,
          label::binary-size(unquote(label_length)),
          message::bitstring>>
      ) do
     label
  end
end
```

---

# This works fine

```elixir
<<0::2, len::6, label::binary-size(len), rst::bitstring>> = <<0,"AAAAA">>
```