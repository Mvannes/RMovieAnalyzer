# A comparison of GroupLens and IMDB data
__Authored by:__
Michael van Nes
500670754

# Table of contents
- [Research](#research)
  * [Datasets](#datasets)
    + [GroupLens / MovieLens](#grouplens--movielens)
    + [IMDB](#imdb)
  * [Research question](#research-question)
- [Processing](#processing)
  * [MovieLens](#movielens)
    + [Choosing a database](#choosing-a-database)
    + [Problems with the data](#problems-with-the-data)
    + [MongoSetup.R](#mongosetupr)
      - [Step 1: Querying](#step-1-querying)
      - [Step 2: Disregard conventions, do looping](#step-2-disregard-conventions-do-looping)
      - [Step 3: Add it all together](#step-3-add-it-all-together)
      - [Step 4: Add it to the database](#step-4-add-it-to-the-database)
  * [IMDB](#imdb-1)
    + [Problems with the data](#problems-with-the-data-1)
    + [IMDBScraper.R](#imdbscraperr)
      - [Step 1: Functionality](#step-1-functionality)
      - [Step 2: Taking data from the internet](#step-2-taking-data-from-the-internet)
      - [Step 3: Using the scraped webpage](#step-3-using-the-scraped-webpage)
  * [Recap](#recap)
- [Shiny Graphs](#shiny-graphs)
  * [What is shiny?](#what-is-shiny)
  * [ui.R](#uir)
  * [server.R](#serverr)
  * [GraphDataHelper](#graphdatahelper)
    + [Libraries](#libraries)
    + [Helper functions](#helper-functions)
- [Comparisons and Conclusions](#comparisons-and-conclusions)
  * [Points of analysis](#points-of-analysis)
  * [Comparisons](#comparisons)
    + [Which dataset has the highest ratings?](#which-dataset-has-the-highest-ratings)
      - [Between 1995 - 2017](#between-1995---2017)
      - [In 2017](#in-2017)
    + [Does the amount of votes influence rating?](#does-the-amount-of-votes-influence-rating)
    + [Does title length influence rating?](#does-title-length-influence-rating)
    + [Which years have the longest titles?](#which-years-have-the-longest-titles)
  * [Conclusion](#conclusion)
  * [Reflection and future corrections](#reflection-and-future-corrections)

# Research
## Datasets
### GroupLens / MovieLens
To start researching something we must first decide what it is that we intend to research. We must also find out where our data will come from. Our first dataset, which had it’s usage set as a requirement for this research, consists of movie data from [MovieLens](https://grouplens.org/datasets/movielens/), a part of the data aggregator GroupLens. For the purposes of having a dataset that is as expansive as possible, we decided to make use of the largeset dataset available. 
>Full: 26,000,000 ratings and 750,000 tag applications applied to 45,000 movies by 270,000 users. >Includes tag genome data with 12 million relevance scores across 1,100 tags. Last updated 8/2017.

This description seemed like it would give us more than sufficient data to use in forming conclusions. The MovieLens data came in the form of multiple `.csv` files. From these files we decided to make use of the following:
* `movies.csv`
For movie data including; Title, Release year, Genres, the movies's unique id in this dataset.
The contents of this file require quite a bit of processing, as the Title and Release year are held in the same column. More on that later however.
* `ratings.csv` 
This is by far the largest file in the dataset, where the entire uncompressed dataset is roughly ~1gb of data, this file alone is ~700 mb. It also contains what is by far the most interesting data. Namely this file contains every rating done for every movie. The fields that are of interest for our analysis are; The movie id (so we can link it with our other csv), the given rating. We are explicitly not making use of the user id that is also in this csv as we want to ensure that we are not processing any personal data.

### IMDB
For our second data set we made use of data webscraped from IMDB, for this we took the top 100 highest grossing movies for each year between 1995 and 2017. This webscraped data contained the Title, the release year, the amount of votes, and the movies genre(s). At the start it also contained the movie's runtime and gross earnings but as these were not available in the MovieLens dataset, it was decided that these should be excluded. An example of the a webscraped page can be found at `http://www.imdb.com/search/title?count=100&release_date=2016,2016&title_type=feature&sort=boxoffice_gross_us,desc` 

## Research question
Research is not complete without a research question.
> When looking at the two datasets, IMDB and Grouplens, which shows a closer grouping of data  points when various pieces of information are set against eachother.

To analyze this we want to be able to do a couple of things. 
* Show a graph
Very obvious, but important nonetheless. We want to be able to show an interactive graph that allows the user to change what values are depicted on the x- and y-axis. Filtering based on the release year will also allow us to further enhance our results.
* Combine data from MovieLens and IMDB
We want to have the ability to show both graphs containing individual data sets, meaning separate graphs for IMDB and MovieLens data, as well as a graph of combined data. 

This sounds simple, and the difficulty will mostly come from the processing of our data. As this research is mostly intended to showcase some skill in R, the main factor for success is the "cool-factor" of our graphs.

# Processing
The following chapter will be about the processing of our datasets into something we can actually use to compare the two data sets. Looking at the data as we get it in it's most pure form, we have a couple of csv files and a couple of web pages. This makes comparisons hard. Of course we could manually draw the graphs that we need, but as we are programmers, and kind of lazy, we're not going to do that. The first step is to normalize the data, starting with the MovieLens data
## MovieLens
A requirement for this research was that one of the datasets must be actively taken from a real database connection. As the IMDB dataset already requires special parsing, the proper target for database connections is the MovieLens data.
### Choosing a database
First, a decisions must be made as to what database we will use. As we're making use of a lot of rough data that doesn't rely too much on interconnectivity, we will opt to make use of a MongoDB database. We start off by loading the completely unparsed data into two different mongo collections using CLI commands.
* `mongoimport -c ratings --type=csv --file=ratings.csv --fields=userId,movieId,rating,timestamp`
Which loads our ratings.csv into a local mongo collection called `ratings`
* `mongoimport -c movies --type=csv --file=movies.csv --fields=movieId,title,genres`
Which loads our movies.csv into local mongo collection called `movies`

### Problems with the data
With this initial setup done, we must now filter the data in these collections to get normalized data. There are a few problems we can identify with the dataset that need to be fixed.
1. The year and title are part of the same field
This is a problem because we want to be able to filter based on year, which is made considerably harder when the year is preceded by an arbitrarily large string of text.
2. The genres are a single string
If we want to make any comparison of genres, we must separate the genres from eachother, turning a single string into a vector. 
3. There is no average rating
All we have is a lot of unrelated ratings, this must be resolved so we can find a single averaged rating for each movie. 
4. The amount of votes is unknown
Similar to the previous issue, we do not know how many people voted on a movie, these also need to be grouped to ensure a comparison is possible.

### MongoSetup.R
Because this is a relatively large amount of data, and the parsing we need to do is heavier than simply copying and pasting the information from one place to another, cleaning this data will be done in a separate R script. The clean data can then be inserted into a new Mongo collection which will make initializing the data for our graphs much faster, as it won't have to be cleaned every run.

#### Step 1: Querying
We start off by forming database connections using the `mongolite` CRAN library. This will allow us to easily query the existing collections, as well as write to a new collection once our data has been filtered.
To establish active connections to our collection we use the following code:
``` R
movies <- mongo(collection = "movies", db = database_name) 
ratings <- mongo(collection = "ratings", db = database_name)
```
Then, we query everything we need from our collections. Querying once is better for performance reasons, a basic design goal is to keep the amount of database interactions to a minimum. 
Our first query limits the amount of fields we retrieve to ensure we only ,get the smallest subset of data we require for analysis. This could be done in R, but when working with a live database that might not be locally hosted it is better to send less data over the line. For a much larger data set even adding a single extra field will dramatically slow down the process of retrieving data.
``` R
all_movies <- movies$find(
    fields = '{"movieId": true, "genres": true, "title": true, "_id": false}'
)
```
Our second query deals with querying our ratings collection for information about votes and ratings, grouped by the movie id.
An option would be to handle the aggregation of data in R, but again, we look to send as little data as possible, and thus leave handling of the aggregation to our database. This is especially important here as this database contains over 700 mb worth of data, a lot of which is not interesting for our analysis.
The following query results in a simple list of movie id's, with their amount of votes and average ratings. 
``` R
all_ratings <- ratings$aggregate(
    '[
        {"$group":{"_id":"$movieId", "votes": {"$sum":1}, "average_rating":{"$avg":"$rating"}}}
    ]',
    options = '{"allowDiskUse":true}'
)
```

#### Step 2: Disregard conventions, do looping
R language conventions dictate that you should almost never have to loop. 
R language conventions dicatate that you should really be using apply functions instead of loops.
Performance tests indicate that looping is often more efficient than apply functions.
The main reason for using apply functions and abstracting bits of code into repeatable functions is because when you're running R scripts on a distributed platform, such as when using mapreduce functions, performance is much better. 
So for that reason, and because we are kind of lazy, and love ourselves some performance gains, this one time script will loop over our dataframe's rows.
The first thing we must do is confirm that our data is valid. Some of the invalid data that we can have occur is having a movie without a movie id. In this case the movie id will be `"movieId"`, which means that we can never associate real ratings to the movie. 
The solution we implement here is to simply skip over the row like so;
``` R
    if (movie$movieId == 'movieId') {
        next
    }
```
Solving our first problem, the fact that the title and release date are in the same field with the unparsed dataset, we make use of the `stringr` library to substring the year from the title.
``` R
    regexp_pattern <- ' \\([0-9]*\\){1}'
    year <- str_match(movie$title, regexp_pattern)[1] %>% 
        gsub(' \\(', '', .) %>%
        gsub('\\)', '', .) %>%
        as.numeric()
```
This is a simple regexp that matches the year, an arbitrary amount of numbers between parentheses. For some movies no year is found. This means that we can't use these movies in our analysis. So these are excluded 
``` R
    if(is.na(year)) {
        next
    }
```
Having extracted the year, we use the same regexp to gsub the year out, leaving us with a proper title. 
``` R 
    title <- gsub(regexp_pattern, '', movie$title)
```
Our genres are a single string right now, separated by `"|"` characters. So we split the string on that character to form a vector of genre strings.
``` R
    genres <- strsplit(movie$genres, "\\|")
```
To get the correct rating and amount of votes we must make use of the data from our `all_ratings` data frame. To get the correct information we filter out anything that doesn't have a movieId field with our movie's id.
We can immediately take the `votes` field. As this has already been cleaned by our mongo query we only need to insert this into our result.
``` R
    movie_ratings <- filter(all_ratings, (all_ratings["_id"] == movie$movieId))
    votes <- movie_ratings$votes
```
Now we'd like to do the same for our rating, but we can't. Why not? IMDB uses a rating system where a score between 1 and 10 is given. MovieLens only goes up to 5. So we must make these two datasets compatible. In this case we opt to multiply the MovieLens data by 2, and  round the resulting number to 2 decimals.
``` R
rating <- round(movie_ratings$average_rating * 2, 2)
```
As a final step of  data cleaning we check if either rating or votes are empty. If they are we toss them out, as no votes means that comparing by vote is rather hard.
``` R
    if(length(votes) == 0 | length(rating) == 0) {
        next
    }
```
#### Step 3: Add it all together
The last part will be to add each row to our dataframe of clean, usefull data. 
``` R 
    parsed_movie <- data.frame(
        Title = title,
        Rating = rating,
        ReleaseYear = year,
        Votes = votes
    )
    parsed_movie$Genre <- genres
    filtered_movies <- rbind(filtered_movies, parsed_movie)
```
Note that the genres are added separately as each row in the data frame is given a vector of genres. The `data.frame()` function doesn't handle this too well so we asign the genres to the correct column after creating it.
Lastly we use `rbind` to append our cleaned data to all the previous rows of clean data.  r(ow)bind lets us append two dataframes with the same columns to eachother, which gives us a complete data frame.
 
#### Step 4: Add it to the database
Now this step has taken quite some time. We don't want to repeat this every time our shiny app is ran. So what we want to do is save our cleaned data to a different mongo collection, satisfying our assignment requirement of using an active data connection, while also greatly improving performance.
``` R
    filtered_db <- mongo(collection = "filtered_movies", db = database_name)
    filtered_db$insert(filtered_movies)
```

## IMDB
### Problems with the data
1. It's on a website.
Our data is on a website. It needs to be locally stored somewhere instead.

I suppose the chapter should be renamed to "problem with the data". There aren't a lot of problems that don't involve simple parsing.
### IMDBScraper.R
Because webscraping shouldn't be done in the same file as database parsing.

#### Step 1: Functionality
Lets start with the first important part of our imdb scraping, identifying that we need to do this a lot. The way we intend to do this is to create a function that will allow us to do our web scraping on demand.
The beauty of functions is that we can reuse them as often as we want. Lets take a look at the signature for our function.
``` R
    scrape_imdb <- function(start_date, end_date)
```
Our function named `scrape_imdb` takes two required parameters. The start date, and the end date. These can then be used inside the function to set the boundaries of our webscraped data.

#### Step 2: Taking data from the internet
This step sounds really hard. This brings up thoughts of sending CLI curls, parsing through straight html, saving that to files, reading them again. Instead we use magic. Or the [rvest](https://github.com/hadley/rvest) webscraping library. Really they're the same thing.
What do we actually need to webscrape data? First we need an url, without an url there is little we can do as this will indicate what webpage we should visit. 
``` R
    base_url <- paste(
        'http://www.imdb.com/search/title?count=100&release_date=',
        'DATE_HERE,DATE_HERE&title_type=feature&sort=boxoffice_gross_us,desc',
        sep=""
    )
```
Of note in this code snippet is that we have two `DATE_HERE` string in our url. This is because the actual url we need to visit must contain a start and end date. Because we want to get the top 100 moviesof every year, this `DATE_HERE` string must be replaced with something useful. 

We also want to ensure that we don't get data from just the start and end date, but also for every year in between. We do this by creating a vector of years like so:
``` R
    release_years <- seq(start_date, end_date, 1)
```
This creates a vector containing the sequence from start date to end date with steps of 1. So for a start date of 2015 and an end date of 2017, the vector will contain 2015, 2016, and 2017.

We then proceed to loop over our sequence of dates, to scrape data from the correct urls. We use gsub to replace the `"DATE_HERE"` placeholders in our base url with the correct year. 
``` R
    for(year in release_years) {
        url <- gsub("DATE_HERE", year, base_url)
```
Then, using the `rvest` library, we can read the entirety of the html page and save this to a variable.
``` R
        page <- read_html(url)
```
Actual magic.

#### Step 3: Using the scraped webpage
Rvest does something really cool. It doesn't just give us html to parse through. It gives us the ability to take information contained in the html elements through css selectors. This makes webscraping the easiest thing, only requiring us to identify the correct css selectors needed. Doing this for the first bit of information we want, the page titles looks like this:
``` R 
 page_titles <- html_nodes(page, '.lister-item-header a') %>%
        html_text()
```
The html nodes function lets us use the correct selector, in this case `.lister-item-header a` to directly take the correct node from the html page object. Piping this to the `html_text` function turns this into simple strings. 
Of course, this is probably one of the easiest things to scrape. What happens when our desired element doesn't have a direct class? Such as with our vote count?
Well every element still has a class, secretly.
``` R 
    page_votes <- html_nodes(page,'.sort-num_votes-visible span:nth-child(2)') %>%
        html_text() %>%
        gsub("\\,", "", .) %>%
        as.numeric()
```
First, we select the correct html element, making use of a direct class name, an element type, and the `nth-child` css selection function. This is piped to get the html text.
A problem exists with this data. The votes use commas to split the number into more readable types. Making these numeric without further parsing will result in a large list of `NA` objects. This is of course wrong, so we must pipe the resulting text to a gsub to remove all commas from the text before making everything numeric.

Our ratings don't suffer from this same problem, so here we can use a much more simple solution for parsing them, sending them directly to a numeric call.
``` R
    page_ratings <- html_nodes(page, '.ratings-imdb-rating strong') %>%
        html_text() %>%
        as.numeric()
```
After parsing our genres, removing newline (`\n`) characters, and splitting the string.
``` R 
    page_genres <- html_nodes(page, '.genre') %>%
        html_text() %>%
        gsub("\n", "", .) %>%
        strsplit(., ", ")
```
We can add all this data to a dataframe, and then use our `rbind` function to append the current year to the rest of the scraped dataset.
``` R
    df <- data.frame(
        Title = page_titles,
        Rating = page_ratings,
        ReleaseYear = year,
        Votes = page_votes
    )
    df$Genre <- page_genres
    imdb <- rbind(imdb, df)
```
As the last part of the function, we return our scraped data, so other placed can make use of the data.
``` R
    return(imdb)
```

## Recap
During this chapter we processed our `.csv` files by moving them into mongo collections, querying those collections, and then reinserting them into a new collection of filtered data, and created a function to actively webscrape IMDB data by using the `rvest` library. 
Now that we have al this data we must use it to show statistics.

# Shiny Graphs
## What is shiny?
Shiny refers to the [rshiny](https://github.com/rstudio/shiny) cran library. This allows the user to make interactive graphs. And as we all know, interactive graphs are much cooler than regular graphs.
In our case we want to use shiny to allow the user to filter results based on release year, and allow the user to select what information they want to display on the x- and y-axis. The core parts of shiny are the `ui.R` and `server.R` files.

## ui.R
The shiny `ui.R` file contains the user interface logic. This decides how information is shown to the user, and the location of this information. Looking at our ui file, we see that we first declare some choices for our user. This is done at first because we do not need these choices to rely on anything else that the user puts in.
``` R
choices <- c("rating", "release_year", "votes", "title_length")
names(choices) <- c("Rating", "Release year", "Number of votes", "Title length")
```
We give the user the option to select the ratings, the release year, the number of votes, and the title length as choices for display on the x- and y-axis. Note that these are given names, allowing us to make use of more convenient programming style values, while displaying nice human readable choices to our user. 

We want to have a nice little sidebar that holds options for the user to affect the graph contents, and a main part of the application that shows graphs and information.
Lets take a look at how we create a nice sidebar first.
``` R
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
    )
```
This results in a sidebar titled `Available filters`, that has three possible inputs. A slider that lets the user select a date range, somewhere between our start year and end year. Two dropdown boxes with the predefined choice values. These are used for selecting what information to show on the x- and y-axis. 

Now that we have our sidebar we should ensure that we have a place to show graphs. We do this by creating a `mainPanel`. Because we are showing information from multiple data sets, and we want to create a comparison between the data sets we will make use of tabs to show a graph that combines our data sets, and a graph for both of the data sets on an individual basis. 
``` R
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
```
Each of our tabs contains a title which explains what the information in the tab is about. 
Furthermore, they contain a plot that shows the actual data, as well as a depressed panel that contains some additional information, ( the amount of movies, the maximum rating, the minimum rating, and the mean rating ). These graphs and blocks of information update when the user makes changes to their selections. 

## server.R
The `server.R` file contains all the background logic that facilitates the showing of graphs based on user input. Most importantly, this is where our graphs are made. Or at least this is where they should be made. As I moved more and more logic to the `server.R` script the file became incredibly cluttered. This is where OOP instincts kicked in, the actual parsing of data into user output should be abstracted away to a different file. Mainly because it improves readability. This means that the first line, and arguably the most important line in the file is to make use of the `source()` function to import the entirety of a helper file, more on that file later, into the `server.R` file.
``` R
    source("GraphDataHelper.R")
```
Once this is done we query for our two datasets. Because we don't want to have to rescrape imdb and requery our database whenever the user makes changes to their selection, we query the full dataset using functions abstracted away to the helper file. These are saved as global variables so we can easely access them later on. While not strictly neccesary to make them global, this allows us to make our querying functions slightly smarter later on. 
``` R
    scraped_stats <<- get_imdb_data(FALSE)
    mongo_stats <<- get_mongo_data(FALSE)
    full_stats <<- rbind(scraped_stats, mongo_stats)
```
More on how these functions work later. For now all we need to know is that we have queried both our data sources and saved them to the correct dataframes, one of which is a combination of both sets. 

Lets move on to the really cool part of our server logic, the part that reacts to the user inputs.

``` R

shinyServer(function(input, output) {
    output$combinedPlot <- get_plot(full_stats, input, colour_on = "is_imdb")
    output$combinedMovies <- get_text_output(full_stats, input, "movie_count")
    output$combinedMaxRating <- get_text_output(full_stats, input, "max_rating")
    output$combinedMinRating <- get_text_output(full_stats, input, "min_rating")
    output$combinedMeanRating <- get_text_output(full_stats, input, "mean_rating")

    output$imdbPlot <- get_plot(scraped_stats, input)
    output$imdbMovies <- get_text_output(scraped_stats, input, "movie_count")
    output$imdbMaxRating <- get_text_output(scraped_stats, input, "max_rating")
    output$imdbMinRating <- get_text_output(scraped_stats, input, "min_rating")
    output$imdbMeanRating <- get_text_output(scraped_stats, input, "mean_rating")

    output$mongoPlot <- get_plot(mongo_stats, input)
    output$mongoMovies <- get_text_output(mongo_stats, input, "movie_count")
    output$mongoMaxRating <- get_text_output(mongo_stats, input, "max_rating")
    output$mongoMinRating <- get_text_output(mongo_stats, input, "min_rating")
    output$mongoMeanRating <- get_text_output(mongo_stats, input, "mean_rating")
})
```
This doesn't look too cool, but I really like the abstractions. All this contains is calling helper functions and setting the correct outputs. Note that we actually pass the input to these functions. This could be altered to pass parts of the input, but since we're operating completely in the reactive context, this works just fine, if a little lazily.

With our promises of coolness denied, we should take a look at the helper funtions we've  written.

## GraphDataHelper
### Libraries
This R script contains a plethora of helper functions required to create our graphs. Lets first take a look at the libraries we use.
``` R
    library(shiny)
    library(dplyr)
    library(ggplot2)
    library(mongolite)
```
[Shiny](https://github.com/rstudio/shiny) allows us to make use of shiny functions for rendering things. The main reason for this to be in the helper file is that the helper contains functions that are used directly in the server logic. 
[Dplyr](https://github.com/tidyverse/dplyr) lets us do some of the filtering we need to properly make use of our user's input.
[Ggplot2](https://github.com/tidyverse/ggplot2) is for rendering really cool graphs.
[Mongolite](https://github.com/jeroen/mongolite) is used for creating mongodb connections.

### Helper functions
The first of our helper functions allow us to globally make use of the same start and end dates. These mainly exist to avoid use of magic numbers, as well as allow us to rapidly change these dates throughout our application, improving maintainability. 
``` R 
    get_start_date <- function () {
        return(1995)
    }
    
    get_end_date <- function() {
        return(2017)
    }
```
Next we have two helper functions that help our other helper functions. ( Yeah it gets a bit complicated. )
These select different data and labels based on the user input. These are of course used to show correct data depending on our user's choices. 
``` R
    select_data <- function(data_set, selection) {
        switch(
            selection,
            rating = {
                return(data_set$Rating)
            },
            votes = {
                return(data_set$Votes)
            },
            release_year = {
                return(data_set$ReleaseYear)
            },
            title_length = {
                return(nchar(as.character(data_set$Title)))
            }
        )
    }
    
    select_label <- function(selection) {
        switch(
            selection,
            rating = {
                return("Rating")
            },
            votes = {
                return("Amount of votes")
            },
            release_year = {
                return("Release year")
            },
            title_length = {
                return("Title length (chars)")
            }
        )
    }
```
When writing these functions we had to make a few choices based on the exactly how generic they should be. We could have opted to separate the functions to provide the exact output for each of the desired outputs. This however would have led to having four times as many functions, that held quite a lot of code duplication. Because we generally prefer to avoid code duplication, we instead wrote a few generic functions, necessitating the creation of the above helper helper functions. 
The first of these generic output functions is the `get_plot` function, which takes a data set, the user input, and a colour_on variable. This last variable is used to decide which field of the data set should be used to colourize the graph. For the graph of combined data we want to separate the imdb data from the MovieLens data. For the individual graphs we want to colourize based on the movie release year. 
``` R 
    get_plot <- function(data_set, input, colour_on="ReleaseYear") {
        plot <- renderPlot({
            filtered_output <- filter(
                data_set,
                ReleaseYear >= input$year[1],
                ReleaseYear <= input$year[2]
            )
            ggplot(
                data = filtered_output,
                aes(
                    x=select_data(filtered_output, input$x),
                    y=select_data(filtered_output, input$y),
                    colour= filtered_output[,colour_on]
                )
            ) + labs(x=select_label(input$x), y=select_label(input$y), colour=colour_on) +
                geom_point() +
                theme_classic()
        })
        return(plot)
    }
```
This function uses the `shiny::renderPlot` function to render a plot. As this is a reactive context, we can make use of the input object to filter the given full data set with the parameters provided by the user. ( In this case filtering out anything that doesn't fall between the given date range. ) The filtered data is then used in creating a ggplot plot, with added colour, and labels based on the input. 
The graph we create is a point graph, or scatterplot. The choice to go for a scatterplot is mainly due to us being interested in data density, and the sheer amount of data makes a scatterplot much more readable than for example a pie chart. 
The plot is then returned to the output. 

The second output rendering function is the `get_text_output` function, which uses the same concepts as the `get_plot` function to render text data.
``` R
    get_text_output <- function (data_set, input, type) {
        text <- renderText({
            filtered_output <- filter(
                data_set,
                ReleaseYear >= input$year[1],
                ReleaseYear <= input$year[2]
            )
            switch(
                type,
                movie_count = {
                    return(paste("Amount of movies: ", nrow(filtered_output)))
                },
                max_rating = {
                    return(paste("Maximum rating: ", max(filtered_output$Rating)))
                },
                min_rating = {
                    return(paste("Minimum rating: ", min(filtered_output$Rating)))
                },
                mean_rating = {
                    return(paste("Mean rating: ", mean(filtered_output$Rating)))
                }
            )
        })
    }
```
The same filtering happens, except instead of rendering a plot, we render text based on the filtered data, and the value of the passed `type` parameter. 

So far we've handled a lot of functions that deal with turning data into ouput, however we're still missing a step where we actually acquire the correct data for the server. The following two functions will handle that task. 
First, to query our MovieLens data from MongoDB.
``` R
get_mongo_data <- function(force_refresh = FALSE) {
    if (!exists("mongo_stats") | force_refresh) {
        database_name <- "test"
        movie_connection <- mongo(collection = "filtered_movies", db = database_name)
        mongo_stats <- movie_connection$find(query =
            paste(
                '{"ReleaseYear": { "$gte": ', get_start_date(), ', "$lte": ', get_end_date(), '}}'
            )
        )
        rm(movie_connection)
        mongo_stats <- mutate(mongo_stats, is_imdb = FALSE)
    }
    return(mongo_stats)
}
```
Lets take a closer look at the function, first we have the optional parameter `force_refresh`. Querying takes time, time we don't really want to be spending every time, so we check if the data environment already contains a correct named variable that holds the dataset. Only when the data isn't already loaded into memory do we want to query it. Of course situations may arise where we want to query the database regardless, to freshen up our data. In this case we can pass the logical `TRUE` to the function, to force it to query the database again.
If we do need to query the database, either because the data environment doesn't hold the `mongo_stats` variable, or because we force refresh, we start by starting up a connection to our `filtered_movies` collection, and querying this with the global `get_start_date` and `get_end_date` functions as ReleaseYear specifiers. 
Once we have queried our data we remove the connection from our environment, which will also close the connection. We don't want to leave connections open after all. 
Though our data has been succesfully queried, we need to add a field for colourization purposes. We use the dplyr mutate function to add the `is_imdb` field to our dataset as being `FALSE`. This seems silly, as our data is obviously not from imdb. However this makes combining the two data sets much easier later on, during the plotting.

Whether we refreshed our data or not, we return the `mongo_stats` to finish up the function.

Lastly, we have a function to query our IMDB dataset, this looks a lot like the one used to query the MovieLens collection.
``` R
    get_imdb_data <- function(force_refresh = FALSE) {
        if (!exists("scraped_stats") | force_refresh) {
            scraped_stats <- scrape_imdb(get_start_date(), get_end_date())
            scraped_stats <- mutate(scraped_stats, is_imdb = TRUE)
        }
        return(scraped_stats)
    }
```
The main difference between this function and the one that queries the MovieLens data is that this function sets the `is_imdb` field to `TRUE` instead of `FALSE`. Apart from that, this one is much shorter as the actual querying logic is done in `IMDBScraper.R::scrape_imdb`. 

# Comparisons and Conclusions
In this chapter we'll take a look at our gathered data, and attempt to answer our research question.

## Points of analysis
We'll first decided what points in our graphs are best for creating comparisons, as the start date and end date are 1995 and 2017 respectively, and we have 4 choices for each of our axis, as well as three graphs per selection, we have 4\*4\*22\*3 = 1056 possible graphs to look at. This seems a bit much, and will no doubt greatly increase the size of this paper. Instead we want to look at our graphs by answering the following questions.
1. Which dataset has the highest ratings when using as many movies as possible?
2. Which dataset has the highest ratings in 2017?
3. Does the amount of votes change how high a rating is given in each dataset?
4. Does title length have any effect on rating?
5. Which years have the longest titles?

During these questions we should keep in mind the shape of the graphs. As the size of the dataset almost always favors the MovieLens dataset, which is much bigger than the scraped data, we must instead look at the way our graphs group together. This will allow for a more accurate comparisont than mere numbers can, and will allow us to answer our main research question.

## Comparisons
### Which dataset has the highest ratings?

#### Between 1995 - 2017
Lets first look at the IMDB dataset. 
The following graph shows the ratings by year. The underlying well panel also gives us the information we're really looking for to answer this question. 
![IMDB rating by release year](https://user-images.githubusercontent.com/8969371/32238526-45706304-be68-11e7-9130-c769f422aaa7.png)

As we can see the highest rating in this dataset is a 9.6, which comes from a movie in 2010.

Comparing this to the MovieLens dataset: 
![MovieLens rating by release year](https://user-images.githubusercontent.com/8969371/32238521-44d6d2d4-be68-11e7-813a-8759528d5db4.png)

We see that the highest rating in this dataset is a 10. Each year has had at least one movie with a solid 10 in the found ratings. 
This can be explained due to larger volume of movies found in the MovieLens database.

#### In 2017
If we filter the year to only show movies found in 2017 and make the same comparison, the following results are found:

For the IMDB dataset we get the following figure:
![IMDB rating in 2017](https://user-images.githubusercontent.com/8969371/32238525-4557f35a-be68-11e7-9f13-d2fab52733be.png)

The max rating in 2017 (As of writing. The year isn't over yet.) is: 8.5

For the MovieLens dataset we get the following figure:
![MovieLens rating in 2017](https://user-images.githubusercontent.com/8969371/32238520-44ba48ee-be68-11e7-840c-588c73408071.png)

The max rating in 2017 (As of writing. The year isn't over yet.) is: 10
We'd expected this when looking at the overal dataset comparison in the previous comparison. As this dataset had a 10 for every year and the IMDB dataset had an overal max of 9.6, the result in this comparison isn't too suprising.

### Does the amount of votes influence rating?
For this comparison we want to look at both the individual datasets, as well as the combined dataset. AS this comparison is mostly about pattern recognition.

Starting of with the combined votes:
![Combined votes by rating](https://user-images.githubusercontent.com/8969371/32238517-4468328e-be68-11e7-9484-fbf71f2ee064.png)

We can clearly see that this combined graph is made less usefull by the discrepancy in number of movies.
However what we can see is that the largest difference between highest and lowest ratings happens in lower voted movies. This makes a lot of sense, as a larger amount of votes will make for a more average grade. If 10000 people vote on a movie, and another comes along and votes a 1, this has little effect on the eventual rating. However if someone comes along on a movie with 1 vote, that new vote counts for a lot more in the calculating of averages.

As the amount of votes goes up, we see that the average rating is higher. This can be explained by saying that as a movie has a higher rating, it will be more popular. A more popular movie will have more people voting on it, as they have seen the movie. 

Another trend we can identify is that movies with higher amounts of votes will never reach a perfect score. This is of course because movie enjoyment is subjective, and when more people watch a movie, there will also be more people that have a negative experience watching it, thus bringing the average down from 10. 

Lets look at the other data sets to see if these observations continue, starting with our IMDB dataset.
![IMDB votes by rating](https://user-images.githubusercontent.com/8969371/32238527-4591bcde-be68-11e7-8284-5844e12b25c8.png)

Here we see the same general shape form in our graph, meaning that the same conclusions can be found here. Interestingly we see that the effect previously found where more votes lead to less perfect scores holds more true here. As the data set is more limited, having chosen to scrape only the top grossing movies for each year, we can assume that these movies are also more popular. Due to this we can see that even movies with fewer votes have lower scores in this data set. Due to a lack of movies with single digit votes.

To further confirm our observations we will look at the MovieLens graph with the same parameters.
![MovieLens votes by rating](https://user-images.githubusercontent.com/8969371/32238522-44f2c584-be68-11e7-8edd-9cac2a5c3ada.png)

In this data set we again see the same shape take hold. This one shows even more clearly that as a movie has less votes, it's rating will move more towards the extreme ratings 1 and 10. 

As all our datasets seem to form the same kind of graph we can take our statements from the first dataset as rough fact. Even though our imdb set has less movies, it still shows the same shape in terms of vote - rating correlation.

The most interesting conclusion here is that if your movie can get people to vote, it will generally not recieve a low rating. Part of this is most assuredly due to the fact that ratings are opinion based, and people will generally voice their opinion if they are strongly in opposition or strongly in agreement with a statement. 
To further expand on this we should normalize the data between the two datasets and see if the same graph shapes hold true. We would also like to add some amount of predictive capability, creating expected ratings based on the amount of votes on a movie. However that will have to be part of another research, as it is not the focus of this one.

### Does title length influence rating?
Here we've decided to go with the silliest factor we could analyze from our dataset. The assumption we've made for this observation is that most popular movies do not have long-, nor short names. Thus we expect that movies with a longer or shorter name than average will trend towards a lower rating.

Lets start by looking at the most general trends in our combined dataset. After which we can confirm our suspicions by comparing the individual datasets.
![Combined rating by title length](https://user-images.githubusercontent.com/8969371/32238514-441e697e-be68-11e7-8796-1cebaf28e6cd.png)

It looks like our suspicion is not at all true. Looking at both extremes on the graph, we see that there does not seem to be a correlation between the length of movies and being on either of the rating extremes. However we do see that no movie with a rating greater than ~8.0 has a title with more than ~75 characters.
All this really means is that if you're making a movie you might not want to give it a really long name. But that doesn't guarentee success, as the same kind of title lengths are found for movies with a rating less than ~2.5. 
Lets confirm these observations in the IMDB graph.
![IMDB rating by title length](https://user-images.githubusercontent.com/8969371/32238523-451fedc0-be68-11e7-898e-2b7daa7b800b.png)

This graph looks interesting, while the shape is roughly the same, the fact that there are less movies in this dataset than in the combined graph leads to a more readable graph. The most important points that can be found here is that in the imdb dataset the title length is much lower than in the combined dataset. The same kind of observations are formed however, the character count for each title only goes down.

Lastly, lets take a look at the MovieLens dataset to further confirm the fact that this graph really says nothing at all.
![MovieLens rating by title length](https://user-images.githubusercontent.com/8969371/32238518-4484921c-be68-11e7-9037-d47b101948e8.png)

The same kind of information looks to be found in this graph. So to conclude, there is no real correlation between title length and movie rating. However, if you have a really long title, your movie is probably average. Usually. 

### Which years have the longest titles?
Lets make one more comparison. Lets try to find out which dataset has the longest title, and in which years the longest titles reside.
![Combined title length by year](https://user-images.githubusercontent.com/8969371/32238515-44409134-be68-11e7-98be-5ca34e03fe19.png)

Looking at this graph we see that the longest title in the combined dataset is ~190 characters, and it's found in 2001.
If we look at the overal trend in our graph we see that title lengths remain relatively consistent throughout the years, though in the last 4 years they seem to trend towards slightly shorter titles when compared to the rest of the dataset. 
Apart from our highest longest year, the next two longest titles were found in 1998 and 1999.

If we look at our other two datasets we can answer our comparison between the two datasets.

![IMDB title length by year](https://user-images.githubusercontent.com/8969371/32238524-453c1752-be68-11e7-9d3d-8d825fbbc676.png)

Lets gather the same facts for this dataset. Which year has the longest title? 2006, at roughly 80 characters. Much shorter than our combined dataset. The two runner ups for this data set are 1996 and 1999. Strangely enough, the same slight downwards trend in title length that we saw in the combined data set is not found in the IMDB data.
A possible explanation for this could be that while average title length has gone down, this is not the case for highly grossing movies, which might trend towards more generic and cookie cutter names. 

Finally, our final graph for this report. Lets look at our title trends for the MovieLens dataset.
![MovieLens title length by year](https://user-images.githubusercontent.com/8969371/32238519-449e4dce-be68-11e7-8c97-bd0d6760a510.png)

Here we see that the combined dataset is massively in favour of the MovieLens data, there are simply much more movies in it, thus overwhelming the scraped IMDB data. This graph looks almost exactly the same as the combined graph, with 2001 as the year with the longest title, followed by 1998 and 1999. 
The trend towards slightly shorter movie titles is most evident in this data set, with a distinct drop from 2014 and onwards.

## Conclusion
Now that we've made some comparisons, lets take a final look at our research question and attempt to answer it.

> When looking at the two datasets, IMDB and Grouplens, which shows a closer grouping of data  points when various pieces of information are set against eachother.

The data gathered from GroupLens (MovieLens) was much more tightly grouped, mostly due to the sheer amount of movies found in this dataset when compared to the webscraped data from IMDB. The most interesting observations we have managed to make during our research seem to be that despite the difference in amount of movies, distinct trends will remain the same. 
Most notably, the shape of graphs remains the same, meaning that if a trend happens in one dataset, such as the reduction in title length in recent years, that same trend can be observed in the other dataset.
So while grouping is much denser in the MovieLens dataset, a direct comparison can still be usefull to verify if a certain trend is consistent amongst different audiences.

## Reflection and future corrections
Looking back on the process of creation there are a couple points that I'm not too happy about.
- The mongo scraping. 
Honestly, loading this into separate collections before filtering the data was a good way to have more practice with advanced queries for R. Or at least, slightly more advanced than a find all. But in a real situation it wouldn't be too practical.
- Disregarding "best" practices.
I completely disregarded the fact that the R community encourages the usage of apply functions when doing anything for a dataset. This promotes the ability to eventually make these analysis operations multi-threaded, or even completely distributed. 
My own solution using a for loop, while faster when running on a single core, does not allow for this easy move to a more distributed reuse of the code. This is something that would eventually be nice to have when expanding the IMDB dataset, getting 1000 movies per year, or even more. This is something that would by the very nature of webscraping be pretty slow right now. 
- Combining datasets without weighing them against eachother.
The MovieLens dataset was incredibly large, literally more than ten times larger than the IMDB dataset. This leads to every combined graph looking almost exactly like the former dataset's individual graph. In a future similar project it would be nice to further normalize these datasets, ensuring that they either have roughly the same amount of data, or that a proper weight is given to the datasets, to ensure the graphs are more meaningful.
- No proper dependency management
R is severely lacking in proper community supported dependency management. Every project seems to include various files that are almost like Make files in that they install all the exact packages that you need. But libraries are entirely too specific, working for version x.x.x and not x.x.y. Honestly, if the R community would adopt something like composer, or gradle, adoption of the language would be much more widespread.

Luckily there were also positives!
- R is really nice
While I disagree with a lot of conventions in terms of using single files, instead of splitting things into separate files and functions, when using R for the purposes of data analysis, it's just lovely. Fast, easy to use functions that make parsing data into a nice visual that has actual meaning so very easy. Having done some analysis in PHP before, the difference is astounding. Looking back at what I'd written in PHP, I feel like the same result could've been accomplished using R in roughly a tenth of the lines.
- Libraries for everything
Do you need a highly specific mapping algorithm that applies only to your kind of dataset? R probably still has a library for that, ready to go at a moments notice. While documentation is often lacking, the code is almost always open source, allowing you to just read that instead. 
- Exciting possibilities
Using the knowledge I've gained in making this small project the possibilities for both real life applications (using this in a work environment), as well as expanding on the current project through creating smart predicitons with machine learning or similar algorithm based predicting just sounds like a really fun thing to do. I will absolutely be looking into that in the future.


All in all I would say that my experience with R so far has been very positive, the positives far outweighing the negatives of the language and it's usage.
