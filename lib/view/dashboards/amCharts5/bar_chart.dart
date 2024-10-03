String generateAM5BarChartHtml({
  required String name,
  required List<Map<String, dynamic>> data,
  required String targetOrigin,
}) {
  return """
<!DOCTYPE html>
<html id='html$name' style="margin: 0; padding: 0; overflow: hidden;">
<head>
    <title>Bar Chart</title>
    <script src="https://cdn.amcharts.com/lib/5/index.js"></script>
    <script src="https://cdn.amcharts.com/lib/5/xy.js"></script>
    <script src="https://cdn.amcharts.com/lib/5/themes/Animated.js"></script>
    <script src="https://cdn.amcharts.com/lib/5/themes/Dark.js"></script>
    <script src="https://cdn.amcharts.com/lib/5/themes/Responsive.js"></script>
  <style>
    body, html {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
    }
    #$name {
      width: 100%;
      height: 100%;
    }
    </style>
</head>
<body>
<div id="$name"><script>window.addEventListener('message', function(event) {
        if (event.data && event.data.type === 'updateChartData') {
            updateChartData(event.data.newData);
        }
        if (event.data && event.data.type === 'updateChartTheme') {
            updateChartTheme(event.data.data);
        }
      });
      am5.addLicense("AM5C-9311-8104-3992-9443");
    </script></div>
<script>

// Create root element
// https://www.amcharts.com/docs/v5/getting-started/#Root_element
let root = am5.Root.new("$name");

// Set themes
// https://www.amcharts.com/docs/v5/concepts/themes/
root.setThemes([
  am5themes_Animated.new(root),
  am5themes_Responsive.new(root)
]);


// Create chart
// https://www.amcharts.com/docs/v5/charts/xy-chart/
var chart = root.container.children.push(am5xy.XYChart.new(root, {
  panX: false,
  panY: false,
  paddingLeft:0
}));


// Add cursor
// https://www.amcharts.com/docs/v5/charts/xy-chart/cursor/
var cursor = chart.set("cursor", am5xy.XYCursor.new(root, {
  behavior: "zoomX"
}));
cursor.lineY.set("visible", false);

var date = new Date();
date.setHours(0, 0, 0, 0);
var value = 100;


// Create axes
// https://www.amcharts.com/docs/v5/charts/xy-chart/axes/
var xAxis = chart.xAxes.push(am5xy.DateAxis.new(root, {
  maxDeviation: 0,
  baseInterval: {
    timeUnit: "month",
    count: 1
  },
  renderer: am5xy.AxisRendererX.new(root, {
    minorGridEnabled:true,
    minorLabelsEnabled:true
  }),
  tooltip: am5.Tooltip.new(root, {})
}));

xAxis.set("minorDateFormats", {
  "day":"dd",
  "month":"MM"
});


// Create axes
var yAxis = chart.yAxes.push(am5xy.ValueAxis.new(root, {
  renderer: am5xy.AxisRendererY.new(root, {})
}));

// Function to update chart data and add extra room to the y-axis
function updateChartData(newData) {
    series.data.setAll(newData);

    // Get the max value from the data
    let maxValue = Math.max(...newData.map(item => item.value));
    
    // Add 5% extra room to the y-axis max
    yAxis.set("max", maxValue * 1.05);

    // Clear previous bullets
    series.bullets.clear();

    // Add bullets with hover functionality
    series.bullets.push(function(root, series, dataItem) {
        let label = am5.Label.new(root, {
            text: "{valueY}",
            centerX: am5.percent(50),
            centerY: am5.percent(70),
            populateText: true,
            visible: false  // Hide label initially
        });

        let bullet = am5.Bullet.new(root, {
            locationX: 0.5,
            locationY: 1,
            sprite: label
        });

        // Store bullet in data item
        dataItem.set("bullet", bullet);

        return bullet;
    });

    // Add hover events to columns
    series.columns.template.events.on("pointerover", function(ev) {
        let dataItem = ev.target.dataItem;
        if (dataItem) {
            let bullet = dataItem.get("bullet");
            if (bullet) {
                bullet.get("sprite").set("visible", true);
            }
        }
    });

    series.columns.template.events.on("pointerout", function(ev) {
        let dataItem = ev.target.dataItem;
        if (dataItem) {
            let bullet = dataItem.get("bullet");
            if (bullet) {
                bullet.get("sprite").set("visible", false);
            }
        }
    });
}

// Add series
var series = chart.series.push(am5xy.ColumnSeries.new(root, {
  name: "Series",
  xAxis: xAxis,
  yAxis: yAxis,
  valueYField: "value",
  valueXField: "date",
  fill: am5.color('#a7c6ed')
}));

series.columns.template.setAll({ strokeOpacity: 0 });

series.data.setAll([${data.join(", ")}]);

function updateChartTheme(isDark) {
  if (isDark == true) {
    root.setThemes([
      am5themes_Animated.new(root),
      am5themes_Dark.new(root),
      am5themes_Responsive.new(root)
    ]);
  }
  else {
    root.setThemes([
      am5themes_Animated.new(root),
      am5themes_Responsive.new(root)
    ]);
  }
}




// Make stuff animate on load
// https://www.amcharts.com/docs/v5/concepts/animations/
series.appear(1000);
chart.appear(1000, 100);
    window.parent.postMessage({chartLoadId: '$name', value: ""}, '$targetOrigin');
</script>
<script>
      const htmlElement = document.getElementById('html$name');
      htmlElement.addEventListener('wheel', function(event) {
        if (event.deltaY > 0) {
          window.parent.postMessage({scrollId: 'down'});
        } else {
          window.parent.postMessage({scrollId: 'up'});
        }
      }, false);
    </script>
</body>
</html>
""";
}
