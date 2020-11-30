defmodule RDF.Mapping.FromRDF do
  @moduledoc false

  alias RDF.{Literal, IRI, Graph, Description}
  alias RDF.Mapping.InvalidValueError
  alias RDF.Mapping.Schema.TypeError

  import RDF.Utils

  def call(mapping, initial, %IRI{} = iri, %Graph{} = graph, opts) do
    property_map = mapping.__property_map__()

    if description = Graph.description(graph, iri) do
      Enum.reduce_while(property_map, {:ok, initial}, fn {property, iri}, {:ok, struct} ->
        objects = Description.get(description, iri)
        property_spec = mapping.__property_spec__(property)

        handle(property, objects, description, graph, property_spec, opts)
        |> case do
          {:ok, nil} ->
            {:cont, {:ok, struct}}

          {:ok, mapped_objects} ->
            {:cont, {:ok, Map.put(struct, property, mapped_objects)}}

          {:error, _} = error ->
            {:halt, error}
        end
      end)
    else
      {:error, "No description of #{inspect(iri)} found."}
    end
  end

  def call(mapping, initial, %IRI{} = iri, %Description{} = description, opts) do
    call(mapping, initial, iri, Graph.new(description), opts)
  end

  def call(_, _, %IRI{}, invalid, _) do
    raise ArgumentError, "invalid input data: #{inspect(invalid)}"
  end

  def call(mapping, initial, iri, data, opts) do
    if iri = IRI.new(iri) do
      call(mapping, initial, iri, data, opts)
    else
      raise ArgumentError, "invalid IRI: #{inspect(iri)}"
    end
  end

  defp handle(property, objects, description, graph, property_spec, opts)

  defp handle(_property, nil, _description, _graph, _property_spec, _opts) do
    {:ok, nil}
  end

  defp handle(_property, objects, _description, _graph, property_spec, _opts) do
    map_values(objects, property_spec.type)
  end

  defp map_values(values, {:set, type}) do
    map_while_ok(values, &map_value(&1, type))
  end

  defp map_values([value], type) do
    map_value(value, type)
  end

  defp map_values(values, type) do
    {:error, TypeError.exception(value: values, type: type)}
  end

  defp map_value(%Literal{} = literal, type) do
    cond do
      not Literal.valid?(literal) ->
        {:error, InvalidValueError.exception(value: literal)}

      is_nil(type) or Literal.is_a?(literal, type) ->
        {:ok, Literal.value(literal)}

      true ->
        {:error, TypeError.exception(value: literal, type: type)}
    end
  end
end
