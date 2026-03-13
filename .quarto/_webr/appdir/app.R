library(shiny)

data_file <- "top_2000.csv"
data_url <- "https://raw.githubusercontent.com/BIFX547-26/airway-report-jess355/main/top_2000.csv"

if (!file.exists(data_file)) {
    download.file(data_url, destfile = data_file, mode = "wb", quiet = TRUE)
}

degs <- read.csv(
    data_file,
    stringsAsFactors = FALSE,
    check.names = FALSE
)
names(degs)[1] <- "gene_id"
degs$plot_padj <- pmax(degs$padj, .Machine$double.xmin)
degs$neg_log10_padj <- -log10(degs$plot_padj)

format_threshold <- function(threshold) {
    formatC(threshold, format = "f", digits = 3)
}

format_fold_change_threshold <- function(threshold) {
    formatC(threshold, format = "f", digits = 2)
}

plot_data <- function(data, padj_threshold, fold_change_threshold) {
    current_data <- data
    current_data$significance <- ifelse(
        !is.na(current_data$padj) &
            current_data$padj < padj_threshold &
            !is.na(current_data$log2FoldChange) &
            abs(current_data$log2FoldChange) >= fold_change_threshold,
        "Significant",
        "Not significant"
    )
    current_data
}

selected_gene_text <- function(gene_row) {
    if (nrow(gene_row) == 0) {
        return("Click a point in the volcano plot to inspect one gene.")
    }

    paste0(
        gene_row$symbol[[1]],
        " (Gene ID: ",
        gene_row$gene_id[[1]],
        ")\nlog2 Fold Change: ",
        round(gene_row$log2FoldChange[[1]], 3),
        "\nAdjusted p-value: ",
        signif(gene_row$padj[[1]], 3),
        "\nClassification: ",
        gene_row$significance[[1]]
    )
}

ui <- page_fluid(
    sliderInput(
        inputId = "significance_threshold",
        label = "Adjusted p-value threshold",
        min = 0.001,
        max = 0.100,
        value = 0.050,
        step = 0.001
    ),
    sliderInput(
        inputId = "fold_change_threshold",
        label = "Minimum absolute log2 fold-change",
        min = 0,
        max = ceiling(max(abs(degs$log2FoldChange), na.rm = TRUE) * 10) / 10,
        value = 0,
        step = 0.1
    ),
    textOutput("significance_summary"),
    plotOutput(
        outputId = "volcano_plot",
        height = "550px",
        click = "volcano_click"
    ),
    verbatimTextOutput("selected_gene")
)

server <- function(input, output, session) {
    current_plot_data <- reactive({
        plot_data(
            degs,
            input$significance_threshold,
            input$fold_change_threshold
        )
    })

    output$significance_summary <- renderText({
        threshold <- input$significance_threshold
        fold_change_threshold <- input$fold_change_threshold
        current_data <- current_plot_data()
        significant_count <- sum(current_data$significance == "Significant")

        paste0(
            significant_count,
            " genes are currently classified as significant at an adjusted p-value threshold of ",
            format_threshold(threshold),
            " and a minimum absolute log2 fold-change of ",
            format_fold_change_threshold(fold_change_threshold),
            "."
        )
    })

    output$volcano_plot <- renderPlot({
        threshold <- input$significance_threshold
        fold_change_threshold <- input$fold_change_threshold
        current_data <- current_plot_data()
        point_colors <- ifelse(
            current_data$significance == "Significant",
            "#D55E00",
            "grey70"
        )

        graphics::par(mar = c(5, 5, 3, 1) + 0.1)
        plot(
            current_data$log2FoldChange,
            current_data$neg_log10_padj,
            pch = 16,
            cex = 0.8,
            col = grDevices::adjustcolor(point_colors, alpha.f = 0.7),
            xlab = "log2 Fold Change",
            ylab = "-log10(Adjusted P-value)",
            main = "Volcano Plot of DEX-treated ASM Cells"
        )
        abline(
            h = -log10(threshold),
            col = "#0072B2",
            lty = 2,
            lwd = 2
        )
        if (fold_change_threshold > 0) {
            abline(
                v = c(-fold_change_threshold, fold_change_threshold),
                col = "#009E73",
                lty = 3,
                lwd = 2
            )
        }

        top_hits <- current_data[current_data$significance == "Significant", , drop = FALSE]
        if (nrow(top_hits) > 0) {
            top_hits <- top_hits[order(top_hits$padj), , drop = FALSE]
            top_hits <- head(top_hits, 8)
            text(
                x = top_hits$log2FoldChange,
                y = top_hits$neg_log10_padj,
                labels = top_hits$symbol,
                pos = 3,
                cex = 0.7
            )
        }

        legend(
            "topright",
            legend = c("Significant", "Not significant"),
            col = c("#D55E00", "grey70"),
            pch = 16,
            bty = "n",
            title = "Significance"
        )
    })

    output$selected_gene <- renderText({
        current_data <- current_plot_data()
        clicked_gene <- nearPoints(
            current_data,
            input$volcano_click,
            xvar = "log2FoldChange",
            yvar = "neg_log10_padj",
            maxpoints = 1,
            threshold = 10
        )

        selected_gene_text(clicked_gene)
    })
}

shinyApp(ui, server)
