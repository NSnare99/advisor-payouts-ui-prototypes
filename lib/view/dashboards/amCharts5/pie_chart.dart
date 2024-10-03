import 'dart:convert';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

extension HexColor on Color {
  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}'
      '${alpha.toRadixString(16).padLeft(2, '0')}';
}

List<Color> _colors = const [
  Color(0xff679de0),
  Color(0xffdcae3e),
  Color(0xff8c8985),
  Color(0xff205493),
  Color(0xffffa947),
  Color(0xff95c7c3),
  Color(0xff75b393),
  Color(0xff6c5b7b),
  Color(0xffa7c6ed),
];

String generateAM5PieChartHtml({
  required String name,
  required List<String> labels,
  required List<String> backgroundColor,
  required List<int> data,
  required String targetOrigin,
  int? innerRadius,
  bool semiCircle = false,
  bool allowLegend = true,
  bool sort = true,
}) {
  // Note: The commented out code and parameters such as labels and backgroundColor are not used in this amCharts example,
  // but I've left them in case you plan to use them for further customization.

  var list = data
      .mapIndexed<String>((index, element) {
        // Directly use the toHex() method to get a hexadecimal color string
        return '{"category": "${labels[index].toString()}", "value": "${element.toString()}"}';
      })
      .toList()
      .sorted((a, b) {
        if (!sort) return 0;
        var aInt = int.parse(jsonDecode(a)['value']?.toString() ?? "");
        var bInt = int.parse(jsonDecode(b)['value']?.toString() ?? "");
        return aInt.compareTo(bInt) * -1;
      })
      .mapIndexed((i, e) {
        Color color = Colors.primaries[Random().nextInt(Colors.primaries.length)];
        if (i < _colors.length) {
          color = _colors[i];
        }
        return '${e.substring(0, e.lastIndexOf('}'))}, "color": "${color.toHex()}"}';
      })
      .join(", ");

  String circleString = """
var root = am5.Root.new("$name");
 

        root.setThemes([
          am5themes_Animated.new(root)
        ]);

        var chart = root.container.children.push( 
          am5percent.PieChart.new(root, {
            layout: root.horizontalLayout,
          ${innerRadius != null ? "innerRadius: am5.percent($innerRadius)," : ""}
          }) 
        );
        // Create series
        var series = chart.series.push(
          am5percent.PieSeries.new(root, {
            fillField: "color",
            name: "Series",
            valueField: "value",
            categoryField: "category",
            legendLabelText: "{category}:",
            legendValueText: "[bold]{valuePercentTotal.formatNumber('0.')}%[/]",
            ${innerRadius != null ? "alignLabels: false," : ""}
          })
        );
        // Add click event to slices
    series.slices.template.events.on("click", function(ev) {
      var slice = ev.target;
      if (slice.isActive) {
        slice.isActive = false;  // Toggle off
      } else {
        series.slices.each(function(item) {
          item.isActive = false;  // Toggle off other slices
        });
        slice.isActive = true;  // Toggle on the clicked slice
        window.parent.postMessage({
          chartId: '$name', 
          value: slice.dataItem.dataContext.value, 
          label: slice.dataItem.dataContext.category
        }, '$targetOrigin');
      }
    });
""";

  String semiCircleString = "";

  if (semiCircle) {
    semiCircleString = """
    /**
 * ---------------------------------------
 * This demo was created using amCharts 5.
 * 
 * For more information visit:
 * https://www.amcharts.com/
 * 
 * Documentation is available at:
 * https://www.amcharts.com/docs/v5/
 * ---------------------------------------
 */

// Create root element
// https://www.amcharts.com/docs/v5/getting-started/#Root_element
var root = am5.Root.new("$name");

// Set themes
// https://www.amcharts.com/docs/v5/concepts/themes/
root.setThemes([
  am5themes_Animated.new(root)
]);

// Create chart
// https://www.amcharts.com/docs/v5/charts/percent-charts/pie-chart/
// start and end angle must be set both for chart and series
var chart = root.container.children.push(am5percent.PieChart.new(root, {
  startAngle: 180,
  endAngle: 360,
  layout: root.verticalLayout,
  innerRadius: am5.percent(50)
}));

// Create series
// https://www.amcharts.com/docs/v5/charts/percent-charts/pie-chart/#Series
// start and end angle must be set both for chart and series
var series = chart.series.push(am5percent.PieSeries.new(root, {
  startAngle: 180,
  endAngle: 360,
  valueField: "value",
  categoryField: "category",
  alignLabels: false,
  fillField: "color"
}));

series.states.create("hidden", {
  startAngle: 180,
  endAngle: 180
});

series.slices.template.setAll({
  cornerRadius: 5
});

series.ticks.template.setAll({
  forceHidden: true
});

// Add click event to slices
    series.slices.template.events.on("click", function(ev) {
      var slice = ev.target;
      if (slice.isActive) {
        slice.isActive = false;  // Toggle off
      } else {
        series.slices.each(function(item) {
          item.isActive = false;  // Toggle off other slices
        });
        slice.isActive = true;  // Toggle on the clicked slice
        window.parent.postMessage({
          chartId: '$name', 
          value: slice.dataItem.dataContext.value, 
          label: slice.dataItem.dataContext.category
        }, '$targetOrigin');
      }
    });
    """;
  }

  String legendString = "";
  if (allowLegend) {
    legendString = """
      series.labels.template.set("forceHidden", true);
        series.ticks.template.set("forceHidden", true);
      // Add legend
      var legend = chart.children.push(am5.Legend.new(root, {
        centerY: am5.percent(50),
        y: am5.percent(50),
        layout: root.verticalLayout,
        height: am5.percent(100),
        verticalScrollbar: scrollbarY,
      }));

      legend.markerRectangles.template.setAll({
        cornerRadiusTL: 10,
        cornerRadiusTR: 10,
        cornerRadiusBL: 10,
        cornerRadiusBR: 10
      });

      legend.data.setAll(series.dataItems);

      legend.events.on("wheel", function(ev) {
        ev.target.events.removeType("wheel");
      });""";
  }

  return """
<!DOCTYPE html>
<html id='html$name' style="margin: 0; padding: 0; overflow: hidden;">
<head>
    <title>Pie Chart</title>
    <script src="https://cdn.amcharts.com/lib/5/index.js"></script>
    <script src="https://cdn.amcharts.com/lib/5/percent.js"></script>
    <script src="https://cdn.amcharts.com/lib/5/themes/Animated.js"></script>
    <script src="https://cdn.amcharts.com/lib/5/themes/Dark.js"></script>
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
      ${semiCircleString != "" ? semiCircleString : circleString}

      // Define data
      var data = [$list];

      
      series.data.setAll(data);

      series.events.on("datavalidated", function() {
        am5.array.each(series.dataItems, function(dataItem) {
          if (dataItem.get("value") == 0) {
            dataItem.hide();
          }
        })
      });
      

      var scrollbarY = am5.Scrollbar.new(root, {
        orientation: "vertical",
      });

      scrollbarY.events.removeType("wheel");

      series.labels.template.setAll({
        text: "{category}: [bold]{valuePercentTotal.formatNumber('0.')}%[/]",
        radius: 2
      });

      $legendString

      function updateChartData(newData) {
        const data = newData;
        const colors = [${_colors.map((e) => '"${e.toHex()}"').toList().join(",")}];
        const labels = ${jsonEncode(labels)};
        // map the data to include category and initial value
        let mappedData = data.map((element, index) => ({
            category: labels[index],
            value: element,
        }));

        // sort the mappedData based on the value in descending order
        ${sort == false ? "" : "mappedData.sort((a, b) => b.value - a.value);"}
        

        //map again to include the color, using the sorted index for color selection
        let finalData = mappedData.map((item, index) => ({
            ...item,
            color: colors[index % colors.length] // Use modulo to cycle through colors if not enough
        }));
        series.data.setAll(finalData);
        ${legendString != '' ? "legend.data.setAll(series.dataItems);" : ""}
      }

      function updateChartTheme(isDark) {
        if (isDark == true) {
          root.setThemes([
            am5themes_Dark.new(root)
          ]);
        }
        else {
          root.setThemes([
            am5themes_Animated.new(root)
          ]);
        }
      }
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
