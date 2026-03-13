library(shiny)

degs <- read.csv("Airway_shinylive_files/top_2000.csv")
degs$plot_padj <- pmax(degs$padj, .Machine$double.xmin)
degs$neg_log10_padj <- -log10(degs$plot_padj)
degs$gene_id <- degs$X

format_threshold <- function(threshold) {
  formatC(threshold, format = "f", digits = 3)
}

format_fold_change_threshold <- function(threshold) {
  formatC(threshold, format = "f", digits = 2)
}

ui <- fluidPage(
  sliderInput(
    "padj_thresh",
    "Adjusted p-value threshold",
    min = 0.001,
    max = 0.100,
    value = 0.050,
    step = 0.001
  ),
  sliderInput(
    "fc_thresh",
    "Minimum absolute log2 fold-change",
    min = 0,
    max = ceiling(max(abs(degs$log2FoldChange), na.rm = TRUE) * 10) / 10,
    value = 0,
    step = 0.1
  ),
  textOutput("significance_summary"),
  plotOutput("volcano_plot", height = "550px")
)

server <- function(input, output, session) {
  current_significance <- reactive({
    !is.na(degs$padj) &
      degs$padj < input$padj_thresh &
      !is.na(degs$log2FoldChange) &
      abs(degs$log2FoldChange) >= input$fc_thresh
  })

  output$significance_summary <- renderText({
    significant_count <- sum(current_significance())

    paste0(
      significant_count,
      " genes are currently classified as significant at an adjusted p-value threshold of ",
      format_threshold(input$padj_thresh),
      " and a minimum absolute log2 fold-change of ",
      format_fold_change_threshold(input$fc_thresh),
      "."
    )
  })

  output$volcano_plot <- renderPlot({
    sig <- current_significance()

    plot(
      degs$log2FoldChange,
      degs$neg_log10_padj,
      pch = 16,
      col = ifelse(sig, "#D55E00B3", "#808080B3"),
      xlab = "log2 Fold Change",
      ylab = "-log10(Adjusted P-value)",
      main = "Volcano Plot of DEX-treated ASM Cells"
    )

    abline(h = -log10(input$padj_thresh), col = "#0072B2", lty = 2, lwd = 2)

    if (input$fc_thresh > 0) {
      abline(v = c(-input$fc_thresh, input$fc_thresh), col = "#009E73", lty = 3, lwd = 2)
    }

    legend(
      "topright",
      legend = c("Significant", "Not significant"),
      col = c("#D55E00", "grey50"),
      pch = 16,
      bty = "n"
    )
  })
}

shinyApp(ui, server)
