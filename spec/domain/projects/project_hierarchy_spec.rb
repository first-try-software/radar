require 'spec_helper'
require 'domain/projects/project_hierarchy'

RSpec.describe ProjectHierarchy do
  it 'lazy loads children via the loader' do
    child = double('Child', name: 'Child')
    hierarchy = described_class.new(
      children_loader: -> { [child] },
      parent_loader: nil
    )

    expect(hierarchy.children).to eq([child])
  end

  it 'returns empty array when children_loader is nil' do
    hierarchy = described_class.new(
      children_loader: nil,
      parent_loader: nil
    )

    expect(hierarchy.children).to eq([])
  end

  it 'lazy loads parent via the loader' do
    parent = double('Parent', name: 'Parent')
    hierarchy = described_class.new(
      children_loader: -> { [] },
      parent_loader: -> { parent }
    )

    expect(hierarchy.parent).to eq(parent)
  end

  it 'returns nil when parent_loader is nil' do
    hierarchy = described_class.new(
      children_loader: -> { [] },
      parent_loader: nil
    )

    expect(hierarchy.parent).to be_nil
  end

  describe 'leaf?' do
    it 'returns true when there are no children' do
      hierarchy = described_class.new(
        children_loader: -> { [] },
        parent_loader: nil
      )

      expect(hierarchy.leaf?).to be(true)
    end

    it 'returns true when children_loader is nil' do
      hierarchy = described_class.new(
        children_loader: nil,
        parent_loader: nil
      )

      expect(hierarchy.leaf?).to be(true)
    end

    it 'returns false when there are children' do
      child = double('Child')
      hierarchy = described_class.new(
        children_loader: -> { [child] },
        parent_loader: nil
      )

      expect(hierarchy.leaf?).to be(false)
    end
  end

  describe 'leaf_descendants' do
    it 'returns the owner when it is a leaf' do
      owner = double('Owner')
      hierarchy = described_class.new(
        children_loader: -> { [] },
        parent_loader: nil,
        owner: owner
      )

      expect(hierarchy.leaf_descendants).to eq([owner])
    end

    it 'returns direct children leaf_descendants when they are all leaves' do
      child1 = double('Child1')
      child2 = double('Child2')
      child1_hierarchy = described_class.new(children_loader: -> { [] }, parent_loader: nil, owner: child1)
      child2_hierarchy = described_class.new(children_loader: -> { [] }, parent_loader: nil, owner: child2)
      allow(child1).to receive(:leaf_descendants).and_return(child1_hierarchy.leaf_descendants)
      allow(child2).to receive(:leaf_descendants).and_return(child2_hierarchy.leaf_descendants)

      owner = double('Owner')
      hierarchy = described_class.new(
        children_loader: -> { [child1, child2] },
        parent_loader: nil,
        owner: owner
      )

      expect(hierarchy.leaf_descendants).to eq([child1, child2])
    end

    it 'returns grandchildren when children are parents' do
      grandchild1 = double('GC1')
      grandchild2 = double('GC2')
      allow(grandchild1).to receive(:leaf_descendants).and_return([grandchild1])
      allow(grandchild2).to receive(:leaf_descendants).and_return([grandchild2])

      child = double('Child')
      allow(child).to receive(:leaf_descendants).and_return([grandchild1, grandchild2])

      owner = double('Owner')
      hierarchy = described_class.new(
        children_loader: -> { [child] },
        parent_loader: nil,
        owner: owner
      )

      expect(hierarchy.leaf_descendants).to eq([grandchild1, grandchild2])
    end
  end

  describe 'derived_state' do
    it 'returns :new when there are no leaf descendants' do
      owner = double('Owner')
      hierarchy = described_class.new(
        children_loader: -> { [] },
        parent_loader: nil,
        owner: owner
      )
      allow(hierarchy).to receive(:leaf_descendants).and_return([])

      result = hierarchy.derived_state([:blocked, :in_progress, :done])

      expect(result).to eq(:new)
    end

    it 'returns first matching state from priority list' do
      child1 = double('Child1', current_state: :in_progress)
      child2 = double('Child2', current_state: :done)
      allow(child1).to receive(:leaf_descendants).and_return([child1])
      allow(child2).to receive(:leaf_descendants).and_return([child2])

      owner = double('Owner')
      hierarchy = described_class.new(
        children_loader: -> { [child1, child2] },
        parent_loader: nil,
        owner: owner
      )
      priority = [:blocked, :in_progress, :done]

      result = hierarchy.derived_state(priority)

      expect(result).to eq(:in_progress)
    end

    it 'returns :blocked when any leaf is blocked' do
      child1 = double('Child1', current_state: :blocked)
      child2 = double('Child2', current_state: :done)
      allow(child1).to receive(:leaf_descendants).and_return([child1])
      allow(child2).to receive(:leaf_descendants).and_return([child2])

      owner = double('Owner')
      hierarchy = described_class.new(
        children_loader: -> { [child1, child2] },
        parent_loader: nil,
        owner: owner
      )
      priority = [:blocked, :in_progress, :done]

      result = hierarchy.derived_state(priority)

      expect(result).to eq(:blocked)
    end

    it 'returns :new when no state matches priority list' do
      child = double('Child', current_state: :unknown)
      allow(child).to receive(:leaf_descendants).and_return([child])

      owner = double('Owner')
      hierarchy = described_class.new(
        children_loader: -> { [child] },
        parent_loader: nil,
        owner: owner
      )

      result = hierarchy.derived_state([:blocked, :done])

      expect(result).to eq(:new)
    end
  end
end
