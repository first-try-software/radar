require 'spec_helper'
require 'domain/projects/set_project_state'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_project_repository'

RSpec.describe SetProjectState do
  it 'fails when the project cannot be found' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :todo)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project not found'])
  end

  it 'fails when an invalid state is provided' do
    project = Project.new(name: 'Status')
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :invalid)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state'])
  end

  it 'fails when state is nil' do
    project = Project.new(name: 'Status')
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: nil)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state'])
  end

  it 'fails when attempting to set state to :new' do
    project = Project.new(name: 'Status', current_state: :todo, children_loader: ->(_) { [] })
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :new)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state'])
  end

  it 'updates the state of a leaf project' do
    project = Project.new(name: 'Leaf', current_state: :new, children_loader: ->(_) { [] })
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :done)

    expect(result.success?).to be(true)
    saved = repository.find('123')
    expect(saved.current_state).to eq(:done)
  end

  it 'allows any state transition for leaf projects' do
    project = Project.new(name: 'Leaf', current_state: :new, children_loader: ->(_) { [] })
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :blocked)

    expect(result.success?).to be(true)
    expect(result.value.current_state).to eq(:blocked)
  end

  it 'cascades state to all leaf descendants of a parent project' do
    child1 = Project.new(name: 'Child1', current_state: :new, children_loader: ->(_) { [] })
    child2 = Project.new(name: 'Child2', current_state: :todo, children_loader: ->(_) { [] })
    parent = Project.new(name: 'Parent', children_loader: ->(_) { [child1, child2] })
    repository = FakeProjectRepository.new(projects: {
      'parent' => parent,
      'child1' => child1,
      'child2' => child2
    })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'parent', state: :on_hold)

    expect(result.success?).to be(true)
    expect(repository.find('child1').current_state).to eq(:on_hold)
    expect(repository.find('child2').current_state).to eq(:on_hold)
  end

  it 'cascades state to grandchildren through intermediate parents' do
    grandchild = Project.new(name: 'GC', current_state: :new, children_loader: ->(_) { [] })
    child = Project.new(name: 'Child', children_loader: ->(_) { [grandchild] })
    grandparent = Project.new(name: 'GP', children_loader: ->(_) { [child] })
    repository = FakeProjectRepository.new(projects: {
      'gp' => grandparent,
      'child' => child,
      'gc' => grandchild
    })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'gp', state: :done)

    expect(result.success?).to be(true)
    expect(repository.find('gc').current_state).to eq(:done)
  end

  it 'returns success after cascading to parent project' do
    child = Project.new(name: 'Child', current_state: :new, children_loader: ->(_) { [] })
    parent = Project.new(name: 'Parent', children_loader: ->(_) { [child] })
    repository = FakeProjectRepository.new(projects: {
      'parent' => parent,
      'child' => child
    })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'parent', state: :in_progress)

    expect(result.success?).to be(true)
    expect(result.value).not_to be_nil
  end
end
