// @flow

import path from "path"
import webpack from "webpack"
import {WDS_PORT} from "./config/webpack/config"
import {isProd} from "./config/webpack/util"

export default {
  entry: [
    "./source/assets/javascripts",
  ],
  output: {
    filename: "js/[name].js",
    path: path.resolve(__dirname, "source/public"),
    publicPath: isProd ? "/" : `http://localhost:${WDS_PORT}/dist/`,
  },
  module: {
    rules: [
      {test: /\.(js|jsx)$/, use: "babel-loader", exclude: /node_modules/},
    ],
  },
  devtool: isProd ? false : "source-map",
  resolve: {
    extensions: [".js", ".jsx"],
  },
  devServer: {
    port: WDS_PORT,
    hot: true,
  },
  plugins: [
    new webpack.optimize.OccurrenceOrderPlugin(),
    new webpack.HotModuleReplacementPlugin(),
    new webpack.NamedModulesPlugin(),
    new webpack.NoEmitOnErrorsPlugin(),
    new webpack.optimize.CommonsChunkPlugin({
      name: "vendor",
      minChunks: module => (module.context && module.context.indexOf("node_modules") !== -1),
    }),
    new webpack.optimize.CommonsChunkPlugin({
      name: "manifest",
    }),
  ],
}
