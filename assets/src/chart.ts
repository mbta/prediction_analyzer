import c3 from "c3"
import "selectize/dist/js/standalone/selectize.js"
import "selectize/dist/css/selectize.bootstrap3.css"

interface DataPoint {
  id: number
  bucket: string
  prodAcc: number
  dgAcc?: number
}

declare global {
  interface Window {
    sortOrderLink: HTMLElement
    dataPoints: DataPoint[]
    dataPredictionAccuracyJSON: any
    chartType: string
    timeframeResolution: string
  }
}

export default () => {
  window.addEventListener("DOMContentLoaded", () => {
    if (document.getElementById("chart-prediction-accuracy")) {
      setupDashboard()
    }

    jQuery("#show-dev-green-check").change((event) => {
      event.preventDefault()
      const showDevGreen = jQuery("#show-dev-green-check")
      if (showDevGreen.is(":checked")) {
        jQuery("#dev-green-data-table").show()
        jQuery("#dev-green-accuracy-total").show()
      } else {
        jQuery("#dev-green-data-table").hide()
        jQuery("#dev-green-accuracy-total").hide()
      }
      setupDashboard()
    })

    const accuracyForm = document.getElementsByClassName("accuracy-form")[0]
    if (accuracyForm) {
      bindFormLinks(accuracyForm)
    }
  })
}

const bindFormLinks = (accuracyForm) => {
  const chartRangeInput = document.getElementById(
    "filters_chart_range"
  ) as HTMLInputElement

  const bindChartRangeLink = (linkId, inputValue) => {
    const link = document.getElementById(linkId)
    if (link) {
      link.addEventListener("click", (event) => {
        event.preventDefault()
        chartRangeInput.value = inputValue
        accuracyForm.submit()
      })
    }
  }

  bindChartRangeLink("link-hourly", "Hourly")
  bindChartRangeLink("link-daily", "Daily")
  bindChartRangeLink("link-by_station", "By Station")
}

const renderDashboard = () => {
  let chartHeight
  let dataType
  let rotateAxes
  let xAxisText
  let xAxisType
  let xAxisRotation
  let sortFunction
  let sortOrder
  let xTickFormat
  let xFormat

  const showDevGreen = jQuery("#show-dev-green-check").is(":checked")

  const sortedProdAccs: any[] = []
  const sortedDgAccs: any[] = []
  const sortedBucketNames: string[] = []

  if (window.sortOrderLink) {
    sortOrder = window.sortOrderLink.getAttribute("data-sort-order")
  } else {
    sortOrder = "by_id"
  }

  if (sortOrder === "by_id") {
    sortFunction = (a, b) => {
      return a.id < b.id ? -1 : 1
    }
  } else {
    sortFunction = (a, b) => {
      return [a.prodAcc, a.dgAcc] < [b.prodAcc, b.dgAcc] ? -1 : 1
    }
  }

  window.dataPoints.sort(sortFunction)

  window.dataPoints.forEach((dataPoint) => {
    sortedProdAccs.push(dataPoint.prodAcc)
    if (showDevGreen) {
      sortedDgAccs.push(dataPoint.dgAcc)
    }
    sortedBucketNames.push(dataPoint.bucket)
  })

  const chartType = window.chartType === "Hourly" && window.timeframeResolution !== "60" ? "SubHourly": window.chartType;

  switch (chartType) {
    case "Hourly": {
      chartHeight = 540
      dataType = "line"
      rotateAxes = false
      xAxisText = "Hour of Day"
      xAxisType = "indexed"
      xAxisRotation = 0
      break
    }
    case "SubHourly": {
      chartHeight = 540
      dataType = "line"
      rotateAxes = false
      xAxisText = "Hour of Day"
      xAxisType = "timeseries"
      xAxisRotation = 90
      xFormat = "%H:%M"
      xTickFormat = x => {
        const dateOffset = x.getHours() < 3 ? 1 : 0;
        let tempDate = new Date();
        const date = new Date(tempDate.getFullYear(), tempDate.getMonth(), tempDate.getDate() + dateOffset, x.getHours(), x.getMinutes())
        return date.toLocaleTimeString('en-US');
      }
      break
    }
    case "Daily": {
      chartHeight = 540
      dataType = "line"
      rotateAxes = false
      xAxisText = ""
      xAxisType = "timeseries"
      xAxisRotation = 75
      break
    }
    case "By Station": {
      chartHeight = window.dataPoints.length * 25
      dataType = "bar"
      rotateAxes = true
      xAxisText = ""
      xAxisType = "category"
      xAxisRotation = 90
      break
    }
  }

  const col1 = ["Prod"].concat(sortedProdAccs)
  let col2
  if (showDevGreen) {
    col2 = ["Dev Green"].concat(sortedDgAccs)
  } else {
    col2 = []
  }
  const xData = ["x"].concat(sortedBucketNames)
  let data
  if (showDevGreen) {
    data = { x: "x", columns: [xData, col1, col2], type: dataType, xFormat: xFormat }
  } else {
    data = { x: "x", columns: [xData, col1], type: dataType, xFormat: xFormat }
  }

  c3.generate({
    bindto: "#chart-prediction-accuracy",
    data,
    color: {
      pattern: ["#1fecff", "#c743f0"],
    },
    axis: {
      rotated: rotateAxes,
      y: {
        label: {
          text: "% Accurate",
          position: "outer-middle",
        },
        max: 1,
        min: 0,
        padding: { top: 0, bottom: 0 },
        tick: {
          format: (x) => {
            return (x * 100).toString() + "%"
          },
        },
      },
      x: {
        height: 200,
        label: {
          text: xAxisText,
          position: "outer-center",
        },
        type: xAxisType,
        tick: {
          format: xTickFormat,
          multiline: false,
          rotate: xAxisRotation,
          culling: false,
        },
      },
    },
    grid: {
      x: {
        show: true,
      },
      y: {
        show: true,
      },
    },
    size: {
      height: chartHeight,
    },
    legend: {
      position: "inset",
    },
  })
}

const setupDashboard = () => {
  jQuery("#filters_stop_ids").selectize({
    dropdownParent: "body",
    placeholder: "Type to search...",
    scrollDuration: 0,
  })
  jQuery("#filters_kinds").selectize({
    dropdownParent: "body",
    placeholder: "(all kinds)",
    scrollDuration: 0,
  })

  const rawData = window.dataPredictionAccuracyJSON
  const prodAccs = rawData.prod_accs
  const showDevGreen = jQuery("#show-dev-green-check").is(":checked")
  let dgAccs
  if (showDevGreen) {
    dgAccs = rawData.dg_accs
  } else {
    dgAccs = []
  }
  const bucketNames = rawData.buckets
  let i

  window.chartType = rawData.chart_type
  window.timeframeResolution = rawData.timeframe_resolution
  window.dataPoints = []

  window.sortOrderLink = document.getElementById(
    "sort-order-link"
  ) as HTMLElement
  if (window.sortOrderLink) {
    window.sortOrderLink.addEventListener("click", toggleSortOrder)
  }

  if (showDevGreen) {
    for (i = 0; i < bucketNames.length; i++) {
      window.dataPoints.push({
        id: i,
        bucket: bucketNames[i],
        prodAcc: prodAccs[i],
        dgAcc: dgAccs[i],
      })
    }
  } else {
    for (i = 0; i < bucketNames.length; i++) {
      window.dataPoints.push({
        id: i,
        bucket: bucketNames[i],
        prodAcc: prodAccs[i],
      })
    }
  }

  renderDashboard()
}

const toggleSortOrder = (event) => {
  event.preventDefault()
  if (window.sortOrderLink.getAttribute("data-sort-order") === "by_id") {
    window.sortOrderLink.innerText = "Sort By Route Order"
    window.sortOrderLink.setAttribute("data-sort-order", "by_accuracy")
  } else {
    window.sortOrderLink.innerText = "Sort By Accuracy"
    window.sortOrderLink.setAttribute("data-sort-order", "by_id")
  }

  renderDashboard()
}

export { bindFormLinks, setupDashboard }
