open System
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Hosting
open Microsoft.Extensions.Hosting
open Microsoft.Extensions.DependencyInjection
open Giraffe

let healthHandler: HttpHandler =
    fun next ctx ->
        let response = {| Status = "healthy"; Timestamp = DateTime.UtcNow |}
        json response next ctx

let debugTestHandler: HttpHandler =
    fun next ctx ->
        let count =
            match ctx.TryGetQueryStringValue "count" with
            | Some c ->
                match Int32.TryParse c with
                | true, n -> n
                | false, _ -> 3
            | None -> 3

        let items = [ for i in 1 .. count -> sprintf "Item %d" i ]
        let response = {| Count = count; Items = items; Timestamp = DateTime.UtcNow |}
        json response next ctx

type WeatherForecast = {
    Date: DateOnly
    TemperatureC: int
    Summary: string
    TemperatureF: int
}

let weatherForecastHandler: HttpHandler =
    fun next ctx ->
        let summaries = [| "Freezing"; "Bracing"; "Chilly"; "Cool"; "Mild"; "Warm"; "Balmy"; "Hot"; "Sweltering"; "Scorching" |]
        let rng = Random.Shared

        let forecasts =
            [1..5]
            |> List.map (fun index ->
                let tempC = rng.Next(-20, 55)
                {
                    Date = DateOnly.FromDateTime(DateTime.Now.AddDays(float index))
                    TemperatureC = tempC
                    Summary = summaries.[rng.Next(summaries.Length)]
                    TemperatureF = 32 + int(float tempC / 0.5556)
                })

        json forecasts next ctx

let webApp =
    choose [
        GET >=> route "/health" >=> healthHandler
        GET >=> route "/debug-test" >=> debugTestHandler
        GET >=> route "/weatherforecast" >=> weatherForecastHandler
    ]

[<EntryPoint>]
let main args =
    let builder = WebApplication.CreateBuilder(args)

    builder.Services.AddGiraffe() |> ignore

    let app = builder.Build()

    app.UseGiraffe(webApp)

    app.Run()

    0