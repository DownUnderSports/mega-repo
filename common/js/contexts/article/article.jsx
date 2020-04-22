import React, {createContext, Component} from 'react'
import { object, shape, func } from 'prop-types'
//import authFetch from 'common/js/helpers/auth-fetch'
import quickSort from 'common/js/helpers/quick-sort'

const articleUrl = '/api/articles'

export const Article = {}

Article.DefaultValues = {
  loaded: false,
  selected: 'all',
  all: [],
  queueCount: 0
}

Article.Context = createContext({
  articleState: {...Article.DefaultValues},
  articleActions: {
    getArticles(){},
  }
})

Article.Decorator = function withArticleContext(Component) {
  return (props) => (
    <Article.Context.Consumer>
      {articleProps => <Component {...props} {...articleProps} />}
    </Article.Context.Consumer>
  )
}

Article.PropTypes = {
  articleState: object,
  articleActions: shape({
    getArticles: func,
  }).isRequired
}

export default class ReduxArticleProvider extends Component {
  constructor(props) {
    super(props)
    this.state = { ...Article.DefaultValues }
  }

  asyncSetState = (args) => new Promise((res) => {
    this.setState(args, res)
  })

  render() {
    return (
      <Article.Context.Provider
        value={{
          articleState: this.state,
          articleActions: {
            /**
             * @returns {array} retrieved - array of articles
             **/
            getArticles: async (selected = false) => {
              selected = `${selected || 'all'}`
              const queueCount = this.state.queueCount + 1,
                    holder = (this.state[selected] || []),
                    startState = {
                      loading: !holder.length,
                      loaded: !!holder.length,
                      selected,
                      queueCount
                    }

              if(startState.loading) startState[selected] = [];

              await this.asyncSetState(startState)

              if(startState.loaded) return holder

              try {
                const newState = {
                  loaded: true,
                  loading: false,
                }
                if(!this.state.all.length) {
                  const result = await fetch(articleUrl),
                        retrieved = await result.json(),
                        ids = {};
                  newState.all = quickSort(retrieved.articles, 'sport_abbr_gender')

                  let lastVal = {}

                  for(let i = 0; i < newState.all.length; i++) {
                    const val = newState.all[i];
                    if(val.sport_abbr_gender !== lastVal.sport_abbr_gender) {
                      if(lastVal.sport_abbr_gender) ids[lastVal.sport_abbr_gender].end = i
                      ids[val.sport_abbr_gender] = {start: i}
                    }
                    lastVal = val;
                  }

                  ids[lastVal.sport_abbr_gender].end = newState.all.length
                  newState.ids = ids
                }

                const slicer = (newState.ids || this.state.ids || {})[selected] || {},
                      all = (newState.all || this.state.all);

                if(selected !== 'all') newState[selected] = all.slice(slicer.start || 0, slicer.end || 0)

                this.asyncSetState(newState)
              } catch(e) {
                console.error(e)
                this.asyncSetState({
                  loaded: true,
                  loading: false,
                  [selected]: [],
                })
              }
            },
          }
        }}
      >
        {this.props.children}
      </Article.Context.Provider>
    )
  }
}
