import React from 'react';
import AuthStatus from 'common/js/helpers/auth-status'
import AsyncComponent from 'common/js/components/component/async'
import { DirectUploadProvider } from 'react-activestorage-provider'
import { DisplayOrLoading } from 'react-component-templates/components'
import { Objected } from 'react-component-templates/helpers';
import SimpleMDE from 'simplemde'
import 'simplemde/dist/simplemde.min.css'

const fundraisingIdeasUrl = `/admin/fundraising_ideas/:id.json`
const fundraisingIdeasImageUrl = `/admin/fundraising_ideas/:id/images/:img_id.json`

export default class FundraisingIdeasShowPage extends AsyncComponent {
  constructor(props) {
    super(props)
    this.state = {
      id: '',
      title: '',
      description: '',
      display_order: '',
      images: [],
      errors: null,
      loading: true,
    }
  }

  get action() {
    return this.ideaAction(this.getIdProp())
  }

  ideaAction = (id) =>
    fundraisingIdeasUrl
      .replace(':id', id || '')
      .replace(/\/?(new)?\.json/i, '.json')

  imageAction = (imgId) =>
    fundraisingIdeasImageUrl
      .replace(':id', this.getIdProp() || '')
      .replace(':img_id', imgId || '')
      .replace(/\/?(new)?\.json/i, '.json')

  UNSAFE_componentWillUpdate(_, nextState) {
    if(nextState && nextState.loading) this.unmountEditor()
  }

  componentDidUpdate(_, prevState) {
    if(
      this.editor
      && (prevState.description !== this.state.description)
      && (this.state.description !== this.editor.value())
    ) {
      this.editor.value(this.state.description)
    } else if(prevState.loading && !this.state.loading) {
      this.createEditor()
    }
  }

  createEditor = async () => {
    if(this.editor || !this._isMounted) return;

    if(this.refs.description) {
      this.editor = new SimpleMDE({
        element: this.refs.description,
        initialValue: this.state.description
      })
      this.editor.codemirror.on("beforeChange", this.beforeMDEChange)
      this.editor.codemirror.on("changes", this.afterMDEChange)
    } else {
      return await new Promise(r => {
        setTimeout(() => this.createEditor().then(r), 100)
      })
    }
  }

  afterFetch = ({ idea, skipTime = false }) => this.setStateAsync({
    loading: false,
    lastFetch: skipTime ? this.state.lastFetch : +(new Date()),
    ...(idea || {}),
    images: idea.images || this.state.images || []
  })

  afterMount = async () => {
    const result = await this.getFundraisingIdea()
    await this.createEditor()
    return result
  }

  beforeUnmount = async () => this.unmountEditor()

  unmountEditor = () => {
    if(this.editor) {
      this.editor.codemirror.off("beforeChange", this.beforeMDEChange)
      this.editor.codemirror.off("changes", this.afterMDEChange)
      this.editor.toTextArea()
      this.editor = null
    }
  }

  beforeMDEChange = () => this.hasChanges = true
  afterMDEChange = () => {
    this.hasChanges = false
    const description = this.editor.value()
    if(this.state.description !== description) this.setState({ description })
  }

  getFundraisingIdea = async () => {
    const id = this.getIdProp()
    this.setState({ loading: true })
    if(!id || (id === 'new')) {
      await this.afterFetch({ idea: { images: [] }})
      return false
    }
    try {
      const result = await fetch(this.action, {timeout: 5000}),
            idea = await result.json()

      if(this._isMounted) return await this.afterFetch({idea})
    } catch(e) {
      console.error(e)
    }
    return true
  }

  getIdProp = () => {
    return ((this.props.match && this.props.match.params) || {}).id
  }

  onIdeaChange = (key, ev) => {
    const value = String(ev.currentTarget.value || '')
    this.setState({[key]: value })
  }

  onTitleChange = (ev) => this.onIdeaChange('title', ev)
  onDescriptionChange = (ev) => this.onIdeaChange('description', ev)
  onOrderChange = (ev) => this.onIdeaChange('display_order', ev)

  handleSubmit = async (ev) => {
    try {
      ev.preventDefault()
      ev.stopPropagation()
    } catch(_) {}

    if(!this.state.loading) this.setState({ loading: true })

    try {
      if(this.hasChanges) return setTimeout(this.handleSubmit, 100)

      const { id, title, description, display_order } =  this.state

      const result = await fetch(this.action, {
        method: id ? 'PATCH' : 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ idea: { title, description, display_order } })
      });

      const idea = await result.json()

      if(this._isMounted) return id ? (await this.afterFetch({idea})) : this.locateIdea(idea)
    } catch(err) {
      await this.handleError(err)
    }
  }

  locateIdea = ({ id }) => {
    this.props.history.push(this.ideaAction(id).replace('.json', ''))
  }

  handleError = async (err) => {
    try {
      const errorResponse = await err.response.json()
      console.error(errorResponse)

      return await this.setStateAsync({
        errors: errorResponse.errors || [ errorResponse.message ],
        loading: false
      })
    } catch(e) {
      console.error(err)
      return await this.setStateAsync({errors: [ err.message ], loading: false})
    }
  }

  renderErrors = () =>
    !!this.state.errors && (
      <div className="alert alert-danger form-group" role="alert">
        {
          this.state.errors.map((v, k) => (
            <div className='row' key={k}>
              <div className="col">
                { v }
              </div>
            </div>
          ))
        }
      </div>
    )

  addImage = () => {
    this.setState((state, _) => {
      for(let i = 0; i < this.state.images.length; i++) {
        if(!this.state.images[i].id) return null
      }

      const images = Objected.deepClone(this.state.images || [])
      images.unshift({})
      return { images }
    })
  }

  selectImage = (ev) => {
    const id    = ev.currentTarget.dataset.id,
          files = ev.currentTarget.files

    console.log(id, files, this.state.images)
    this.setState((state, _) => {
      for (let i = 0; i < this.state.images.length; i++) {
        const img = this.state.images[i]

        if(
          (String(img.id || '') === String(id))
          || (!id && !img.id)
        ) {
          const images = Objected.deepClone(this.state.images)
          images[i].files = files

          return { images }
        }
      }
    })
  }

  resetImgUpload = (ev) => {
    const id = ev.currentTarget.dataset.id

    this.setState((state, _) => {
      for (let i = 0; i < this.state.images.length; i++) {
        const img = this.state.images[i]

        if(
          (String(img.id || '') === String(id))
          || (!id && !img.id)
        ) {
          const images = Objected.deepClone(this.state.images)
          images[i].files = []

          return { images }
        }
      }
    })
  }

  handleUpload = async (signedIds) => {
    if(!this.state.loading) this.setState({ loading: true })

    try {
      const result = await fetch(this.imageAction(), {
        method: 'POST',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
        body: JSON.stringify({ image: { file: signedIds[0] } })
      });

      await result.json()

      if(this._isMounted) return await this.getFundraisingIdea()
    } catch(err) {
      await this.handleError(err)
    }
  }

  destroyImage = async (ev) => {
    ev.preventDefault()
    ev.stopPropagation()

    const id = ev.currentTarget.dataset.id
    this.setState({ loading: true })

    try {
      const result = await fetch(this.imageAction(id), {
        method: 'DELETE',
        headers: {
          "Content-Type": "application/json; charset=utf-8"
        },
      });

      await result.json()

      if(this._isMounted) return await this.getFundraisingIdea()
    } catch(err) {
      await this.handleError(err)
    }
  }

  render() {
    const {
      loading,
      id: serverId = '',
      title = '',
      description = '',
      display_order = '',
      images = []
    } = this.state || {},
    id = this.getIdProp() || 'new'

    return (
      <div key={id} className="FundraisingIdeas ShowPage">
        <DisplayOrLoading display={!loading}>
          <section className='idea-pages-wrapper mt-5' id='idea-pages-wrapper'>
            <header>
              <h1 className='text-center below-header'>
                <span>
                  Fundraising Idea - {serverId ? 'Create' : 'Edit'}
                </span>
              </h1>
            </header>
            { this.renderErrors() }
            <form
              action={this.action}
              onSubmit={this.handleSubmit}
            >
              <div className="form-group">
                <label htmlFor="idea_title">Title</label>
                <input
                  type="text"
                  id="idea_title"
                  className="form-control"
                  value={title || ''}
                  name="title"
                  onChange={this.onTitleChange}
                  required
                />
              </div>
              <div className="form-group">
                <label htmlFor="idea_description">Description (optional)</label>
                <textarea
                  ref="description"
                  id="idea_description"
                  className="form-control"
                  value={description || ''}
                  name="description"
                  onChange={this.onDescriptionChange}
                  required
                />
              </div>
              <div className="form-group">
                <label htmlFor="idea_display_order">
                  Order (lowest goes first on page; empty values go last)
                </label>
                <input
                  type="number"
                  step="1"
                  min="0"
                  id="idea_display_order"
                  className="form-control"
                  value={String(display_order) === '0' ? display_order : (display_order || '')}
                  name="display_order"
                  onChange={this.onOrderChange}
                />
              </div>
              <div className="row">
                <div className="col"></div>
                <div className="col-auto">
                  <button type="submit" className="btn btn-block btn-primary">
                    Submit
                  </button>
                </div>
              </div>
            </form>
            { this.renderErrors() }
          </section>
          { !!serverId && this.renderImages(images || []) }
        </DisplayOrLoading>
      </div>
    );
  }

  renderImages = (images) =>
    <section className='idea-pages-wrapper mt-5' id='idea-pages-wrapper'>
      <header>
        <h3 className='text-center'>
          <hr/>
            <div className="row form-group">
              <div className="col-auto"></div>
              <div className="col">
                Images
              </div>
              <div className="col-auto">
                <button
                  type="button"
                  className="btn btn-block btn-success"
                  onClick={this.addImage}
                >
                  Add Image
                </button>
              </div>
            </div>
          <hr/>
        </h3>
      </header>

      <div className="row">
        {
          images.map(
            img =>
              (!!img.src || !!img.id)
                ? this.renderExistingImage(img)
                : this.renderNewImage(img)
          )
        }
      </div>
    </section>

  renderExistingImage = ({
    id: imgId = '',
    alt = '',
    display_order = '',
    src = '',
  }) =>
    <div key={imgId || 'new'} className="col-4">
      <form
        id={`image_form_${imgId || 'new'}`}
        action={this.imageAction(imgId)}
        onSubmit={this.handleImageSubmit}
      >
        <div className="card form-group">
          <img src={src} alt={alt} className="card-img-top" />
          <div className="card-body">
            <div className="form-group">
              <label htmlFor={`img_${imgId}_alt`}>Summary (Accessibility Field)</label>
              <input
                type="text"
                data-id={imgId}
                id={`img_${imgId}_alt`}
                className="form-control"
                value={alt || ''}
                name="alt"
                onChange={this.onTitleChange}
                required
              />
            </div>
            <div className="form-group">
              <label htmlFor={`img_${imgId}_display_order`}>
                Order (lowest goes first on page; empty values go last)
              </label>
              <input
                type="number"
                step="1"
                min="0"
                id={`img_${imgId}_display_order`}
                className="form-control"
                value={String(display_order) === '0' ? display_order : (display_order || '')}
                name="display_order"
                onChange={this.onOrderChange}
              />
            </div>
            <div className="row">
              <div className="col-auto">
                <button
                  type="submit"
                  className="btn btn-block btn-danger"
                  onClick={this.destroyImage}
                  data-id={imgId}
                >
                  Delete
                </button>
              </div>
              <div className="col"></div>
              <div className="col-auto">
                <button type="submit" className="btn btn-block btn-primary">
                  Save
                </button>
              </div>
            </div>
          </div>
        </div>
      </form>
    </div>

  renderNewImage = ({
    files = [],
    fileErrors = null
  }) =>
    <DirectUploadProvider
      key="new"
      headers={{
        ...AuthStatus.headerHash,
        'X-CSRF-Token': '',
        'Content-Type': 'application/json;charset=UTF-8',
      }}
      onSuccess={this.handleUpload}
      render={({ handleUpload, uploads, ready }) => {
        return (
          <div className="col-12">
            <div className="row">
              <div className="col form-group">
                <div className="input-group">
                  <div className="input-group-prepend">
                    <i className="input-group-text material-icons">image</i>
                  </div>
                  <div className="custom-file">
                    <input
                      type="file"
                      id="new_image_input"
                      name="new_image_input"
                      className="form-control-file"
                      placeholder='select photo'
                      onChange={this.selectImage}
                      disabled={!ready}
                    />
                    <label className="custom-file-label" htmlFor="new_image_input">
                      {
                        (
                          files && files.length
                        ) ? files[0].name : 'Choose file...'
                      }
                    </label>
                  </div>
                </div>
              </div>
              <div className='col-2 form-group'>
                <button
                  className='btn btn-block btn-primary'
                  disabled={!ready || !files || !files.length}
                  onClick={e => {
                    e.preventDefault()
                    e.stopPropagation()
                    handleUpload(files)
                  }}
                >
                  Submit
                </button>
              </div>
              <div className="col-12">
                {
                  (fileErrors || []).map((err, i) => (
                    <div className='row' key={i}>
                      <div className="col-12 text-danger">
                        <p>
                         {err}
                        </p>
                      </div>
                    </div>
                  ))
                }
                {uploads.map(upload => {
                  switch (upload.state) {
                    case 'waiting':
                      return <p key={upload.id}>Waiting to upload {upload.file.name}</p>
                    case 'uploading':
                      return (
                        <p key={upload.id}>
                          Uploading {upload.file.name}: {upload.progress}%
                        </p>
                      )
                    case 'error':
                      return (
                        <p key={upload.id}>
                          Error uploading {upload.file.name}: {upload.error}
                          <button
                            className='btn btn-block mt-3 btn-warning'
                            onClick={this.resetImgUpload}
                          >
                            Reset Form
                          </button>
                        </p>
                      )
                    case 'finished':
                      return <p key={upload.id}>Finished uploading {upload.file.name}</p>
                    default:
                      return <p key={upload.id}>An Unknown Error Occured</p>
                  }
                })}
              </div>
            </div>
          </div>
        )
      }}
    />
}
