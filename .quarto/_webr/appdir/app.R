library(shiny)

gist <- "https://gist.githubusercontent.com/johnsonra/121eb61bf4b09e4258b78e341b1819e9/raw/9d4d1650713378ce59e06a21b62f940433100a81/top_2000.csv"
download.file(gist, 'top_2000.csv')
top_2000 <- read.csv('top_2000.csv')
top_2000$nl10p <- -log10(top_2000$padj)

ui <- fluidPage(
  sliderInput("threshold", label = "Significance threshold (p_adj)",
              min = 0.001, max = 0.1, value = 0.05, step = 0.001),
  plotOutput("volcano")
)

server <- function(input, output) {
  output$volcano <- renderPlot({
    top_2000$sig <- top_2000$padj < input$threshold
    cols <- adjustcolor(ifelse(top_2000$sig, 'orange', 'black'), alpha.f = 0.3)

    # sqrt-scaled y axis: transform data, then relabel
    y_ticks <- c(0, 10, 25, 50, 75, 100)
    plot(top_2000$log2FoldChange, sqrt(top_2000$nl10p),
         col = cols, pch = 16,
         xlab = expression(log[2] ~ "Fold Change"),
         ylab = expression(-log[10] ~ p),
         yaxt = 'n',
         bty = 'l')
    axis(2, at = sqrt(y_ticks), labels = y_ticks)

    legend("topright",
           legend = c(paste0("< ", input$threshold),
                      paste0("\u2265 ", input$threshold)),
           col = adjustcolor(c('orange', 'black'), alpha.f = 0.8),
           pch = 16,
           title = expression(p[adj]),
           bty = 'n')
  })
}

shinyApp(ui, server)
