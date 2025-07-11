import c3 from "c3"
import "selectize/dist/js/standalone/selectize.js"
import "selectize/dist/css/selectize.bootstrap3.css"
import datepicker from "js-datepicker"

interface DataPoint {
  id: number
  bucket: string
  prodAcc: number
  dgAcc?: number
  dbAcc?: number
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
    const setSectionVisibility = (env: string) => {
      const showSectionCheckbox = jQuery(`#show-${env}-check`)
      const showSection = showSectionCheckbox.is(":checked")

      jQuery(`#${env}-data-table-col`).css(
        "display",
        showSection ? "block" : "none"
      )
      jQuery(`#${env}-accuracy-total`).css(
        "display",
        showSection ? "block" : "none"
      )
    }

    setSectionVisibility("dev-green")
    setSectionVisibility("dev-blue")

    if (document.getElementById("chart-prediction-accuracy")) {
      setupDashboard()
    }

    jQuery("#show-dev-green-check").change((event) => {
      event.preventDefault()
      setSectionVisibility("dev-green")
      setupDashboard()
    })

    jQuery("#show-dev-blue-check").change((event) => {
      event.preventDefault()
      setSectionVisibility("dev-blue")
      setupDashboard()
    })

    const accuracyForm = document.getElementsByClassName("accuracy-form")[0]
    if (accuracyForm) {
      bindFormLinks(accuracyForm)
      accuracyForm.addEventListener("submit", () => {
        jQuery(".activity-indicator-container").show()
      })
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
        jQuery(".activity-indicator-container").show()
        event.preventDefault()
        chartRangeInput.value = inputValue
        accuracyForm.submit()
      })
    }
  }

  jQuery(".mode-button").on("click", () => {
    jQuery(".activity-indicator-container").show()
  })

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
  const showDevBlue = jQuery("#show-dev-blue-check").is(":checked")

  const sortedProdAccs: any[] = []
  const sortedDgAccs: any[] = []
  const sortedDbAccs: any[] = []
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
    if (showDevBlue) {
      sortedDbAccs.push(dataPoint.dbAcc)
    }
    sortedBucketNames.push(dataPoint.bucket)
  })

  const chartType =
    window.chartType === "Hourly" && window.timeframeResolution !== "60"
      ? "SubHourly"
      : window.chartType

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
      xTickFormat = (x) => {
        const dateOffset = x.getHours() < 3 ? 1 : 0
        const tempDate = new Date()
        const date = new Date(
          tempDate.getFullYear(),
          tempDate.getMonth(),
          tempDate.getDate() + dateOffset,
          x.getHours(),
          x.getMinutes()
        )

        return date.toLocaleTimeString("en-US")
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
  const xData = ["x"].concat(sortedBucketNames)

  const columns = [xData, col1]

  if (showDevGreen) {
    const col2: any = ["Dev Green"].concat(sortedDgAccs)
    columns.push(col2)
  }
  if (showDevBlue) {
    const col3: any = ["Dev Blue"].concat(sortedDbAccs)
    columns.push(col3)
  }
  const data: any = { x: "x", columns, type: dataType, xFormat }

  const pattern = ["#c743f0"]
  if (showDevGreen) {
    pattern.push("#72ff13")
  }
  if (showDevBlue) {
    pattern.push("#1fecff")
  }
  c3.generate({
    bindto: "#chart-prediction-accuracy",
    data,
    color: {
      pattern,
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

const setupDatePickers = () => {
  const padZero = (value) => (value < 10 ? `0${value}` : value)

  const dateFormatter = (input, date) => {
    const year = date.getFullYear()
    const month = padZero(date.getMonth() + 1)
    const day = padZero(date.getDate())

    input.value = `${year}-${month}-${day}`
  }

  const normalizeSelectedDate = (value) => {
    const newDate = new Date(value)
    const offset = newDate.getTimezoneOffset()

    if (newDate.getHours() !== 0) {
      newDate.setHours(newDate.getHours() + offset / 60)
      newDate.setMinutes(newDate.getMinutes() + (offset % 60))
    }

    return newDate
  }

  const serviceDateInput = document.querySelector(
    "#filters_service_date"
  ) as HTMLInputElement
  if (serviceDateInput) {
    datepicker(serviceDateInput, {
      dateSelected: normalizeSelectedDate(serviceDateInput.value),
      formatter: dateFormatter,
      showAllDates: true,
    })
  }

  const dateStartInput = document.querySelector(
    "#filters_date_start"
  ) as HTMLInputElement
  const dateEndInput = document.querySelector(
    "#filters_date_end"
  ) as HTMLInputElement
  if (dateStartInput && dateEndInput) {
    datepicker(dateStartInput, {
      dateSelected: normalizeSelectedDate(dateStartInput.value),
      formatter: dateFormatter,
      showAllDates: true,
    })
    datepicker(dateEndInput, {
      dateSelected: normalizeSelectedDate(dateEndInput.value),
      formatter: dateFormatter,
      showAllDates: true,
    })
    const chartElement = document.getElementById("chart-prediction-accuracy")
    if (chartElement) {
      chartElement.setAttribute("datePickerAdded", "true")
    }
  }
}

const setupDashboard = () => {
  if (
    !document
      .getElementById("chart-prediction-accuracy")
      ?.hasAttribute("datePickerAdded")
  ) {
    setupDatePickers()
  }

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
  const showDevBlue = jQuery("#show-dev-blue-check").is(":checked")
  const dgAccs = showDevGreen ? rawData.dg_accs : []
  const dbAccs = showDevBlue ? rawData.db_accs : []
  const bucketNames = rawData.buckets

  window.chartType = rawData.chart_type
  window.timeframeResolution = rawData.timeframe_resolution
  window.dataPoints = []

  window.sortOrderLink = document.getElementById(
    "sort-order-link"
  ) as HTMLElement
  if (window.sortOrderLink) {
    window.sortOrderLink.addEventListener("click", toggleSortOrder)
  }

  for (let i = 0; i < bucketNames.length; i++) {
    const chartDataPoint = {
      id: i,
      bucket: bucketNames[i],
      prodAcc: prodAccs[i],
    }

    Object.assign(
      chartDataPoint,
      showDevGreen && { dgAcc: dgAccs[i] },
      showDevBlue && { dbAcc: dbAccs[i] }
    )
    window.dataPoints.push(chartDataPoint)
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
