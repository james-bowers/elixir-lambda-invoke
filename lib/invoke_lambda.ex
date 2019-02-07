defmodule InvokeLambda do
  alias InvokeLambda.{AuthorizationHeader, Utils, CredentialStore}

  @aws_endpoint_version "2015-03-31"

  def invoke(function_name, %{role: _} = options) do
    params = build_params(function_name, options)

    HTTPoison.post(
      params.invoke_lambda_url,
      post_body(),
      params.headers
    )
  end

  def build_params(function_name, options) do
    %{region: "eu-west-1", function_name: function_name, service: "lambda"}
    |> Map.merge(options)
    |> put_credentials
    |> put_date
    |> put_invoke_lambda_url
    |> put_headers
  end

  def post_body, do: ""

  def put_invoke_lambda_url(params) do
    Map.put(
      params,
      :invoke_lambda_url,
      URI.encode(
        "https://lambda.#{params.region}.amazonaws.com/#{@aws_endpoint_version}/functions/#{
          params.function_name
        }/invocations"
      )
    )
  end

  defp put_date(params), do: Map.put(params, :date, DateTime.utc_now())

  defp put_headers(params), do: Map.put(params, :headers, build_headers(params))

  defp put_credentials(params) do
    case CredentialStore.retrieve_for_role(params.role) do
      {:ok, credentials} -> Map.put(params, :credentials, credentials)
      {:error, error} -> raise error
    end
  end

  defp build_headers(params) do
    params
    |> build_base_headers
    |> add_auth_headers(params)
  end

  defp build_base_headers(params) do
    parsed_uri = URI.parse(params.invoke_lambda_url)

    [
      {"host", parsed_uri.host},
      {"x-amz-date", Utils.date_in_iso8601(params.date)}
    ]
  end

  defp add_auth_headers(base_headers, params) do
    authorization = AuthorizationHeader.build(params, base_headers)

    base_headers ++
      [
        {"authorization", authorization},
        {"x-amz-security-token", params.credentials.aws_token}
      ]
  end
end