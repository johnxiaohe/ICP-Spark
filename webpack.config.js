require('dotenv').config()
const path = require('path')
const webpack = require('webpack')
const HtmlWebpackPlugin = require('html-webpack-plugin')
const TerserPlugin = require('terser-webpack-plugin')
const CopyPlugin = require('copy-webpack-plugin')

const isDevelopment = process.env.NODE_ENV !== 'production'

const frontendDirectory = 'spark_frontend'

const frontend_entry = path.join('src', frontendDirectory, 'src', 'index.html')

const tailwindcss = require('tailwindcss')

module.exports = {
  target: 'web',
  mode: isDevelopment ? 'development' : 'production',
  entry: {
    // The frontend.entrypoint points to the HTML file for this build, so we need
    // to replace the extension to `.js`.
    index: path.join(__dirname, frontend_entry).replace(/\.html$/, '.jsx'),
  },
  devtool: isDevelopment ? 'source-map' : false,
  optimization: {
    minimize: !isDevelopment,
    minimizer: [new TerserPlugin()],
  },
  resolve: {
    alias: {
      '@': path.join(__dirname, 'src', frontendDirectory, 'src'),
    },
    extensions: ['.js', '.ts', '.jsx', '.tsx'],
    fallback: {
      assert: require.resolve('assert/'),
      buffer: require.resolve('buffer/'),
      events: require.resolve('events/'),
      stream: require.resolve('stream-browserify/'),
      util: require.resolve('util/'),
    },
  },
  output: {
    filename: 'static/js/[name].js',
    path: path.join(__dirname, 'dist', frontendDirectory),
  },

  // Depending in the language or framework you are using for
  // front-end development, add module loaders to the default
  // webpack configuration. For example, if you are using React
  // modules and CSS as described in the "Adding a stylesheet"
  // tutorial, uncomment the following lines:
  // module: {
  //  rules: [
  //    { test: /\.(ts|tsx|jsx)$/, loader: "ts-loader" },
  //    { test: /\.css$/, use: ['style-loader','css-loader'] }
  //  ]
  // },
  plugins: [
    new HtmlWebpackPlugin({
      template: path.join(__dirname, frontend_entry),
      cache: false,
    }),
    new webpack.EnvironmentPlugin([
      ...Object.keys(process.env).filter((key) => {
        if (key.includes('CANISTER')) return true
        if (key.includes('DFX')) return true
        return false
      }),
    ]),
    new webpack.ProvidePlugin({
      Buffer: [require.resolve('buffer/'), 'Buffer'],
      process: require.resolve('process/browser'),
    }),
    new CopyPlugin({
      patterns: [
        {
          from: `src/${frontendDirectory}/src/.ic-assets.json*`,
          to: '.ic-assets.json5',
          noErrorOnMissing: true,
        },
      ],
    }),
  ],
  // proxy /api to port 4943 during development.
  // if you edit dfx.json to define a project-specific local network, change the port to match.
  devServer: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8080',
        changeOrigin: true,
        pathRewrite: {
          '^/api': '/api',
        },
      },
    },
    static: path.resolve(__dirname, 'src', frontendDirectory, 'assets'),
    hot: true,
    watchFiles: [path.resolve(__dirname, 'src', frontendDirectory)],
    liveReload: true,
    historyApiFallback: true, // 解决开发环境刷新路由 404 的问题
  },
  module: {
    rules: [
      {
        test: /.(js|jsx)$/, // 匹配.ts, tsx文件
        use: {
          loader: 'babel-loader',
          options: {
            // 预设执行顺序由右往左,所以先处理ts,再处理jsx
            presets: ['@babel/preset-react'],
          },
        },
      },
      {
        test: /\.css$/, //匹配 css 文件
        use: [
          'style-loader',
          'css-loader',
          {
            loader: 'postcss-loader',
            options: {
              postcssOptions: { plugins: [tailwindcss] },
            },
          },
        ],
      },
      {
        test: /\.less$/i,
        use: [
          // compiles Less to CSS
          'style-loader',
          'css-loader',
          'less-loader',
        ],
      },
    ],
  },
}
