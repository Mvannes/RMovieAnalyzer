library(shiny)
library(magrittr)

source("GraphDataHelper.R")

# Init choices with choice labels.
choices <- c("rating", "release_year", "votes", "title_length")
names(choices) <- c("Rating", "Release year", "Number of votes", "Title length")

# Define UI for application that draws a histogram
shinyUI(fluidPage(

    # Application title
    titlePanel("IMDB - Grouplens movie data", windowTitle = "IMDB - Grouplens movie data"),

    # Sidebar with a slider input for year selection
    sidebarLayout(
        sidebarPanel(
            h4("Available filters"),
            sliderInput(
                "year",
                paste("Input year (", get_start_date(), "-", get_end_date(), ")"),
                min = get_start_date(),
                max = get_end_date(),
                c(get_start_date(), get_end_date()),
                step = 1,
                sep=""
            ),
            selectInput(
                "x",
                "X-axis",
                choices
            ),
            selectInput(
                "y",
                "Y-axis",
                choices
            )
        ),
        mainPanel(
            tabsetPanel(
                type="tabs",
                tabPanel(
                    "Combined",
                    plotOutput("combinedPlot"),
                    wellPanel(
                        textOutput("combinedMovies"),
                        textOutput("combinedMaxRating"),
                        textOutput("combinedMinRating"),
                        textOutput("combinedMeanRating")
                    )
                ),
                tabPanel(
                    "IMDB",
                    plotOutput("imdbPlot"),
                    wellPanel(
                        textOutput("imdbMovies"),
                        textOutput("imdbMaxRating"),
                        textOutput("imdbMinRating"),
                        textOutput("imdbMeanRating")
                    )
                ),
                tabPanel(
                    "GroupLens",
                    plotOutput("mongoPlot"),
                    wellPanel(
                        textOutput("mongoMovies"),
                        textOutput("mongoMaxRating"),
                        textOutput("mongoMinRating"),
                        textOutput("mongoMeanRating")
                    )
                )
            )
        )
    )
))
