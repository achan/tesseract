require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  test "new renders form" do
    get new_workspace_path
    assert_response :success
  end

  test "create with valid params" do
    assert_difference "Workspace.count", 1 do
      post workspaces_path, params: { workspace: { team_id: "T_NEW", team_name: "New Workspace" } }
    end
    assert_redirected_to root_path
  end

  test "create with invalid params renders new" do
    assert_no_difference "Workspace.count" do
      post workspaces_path, params: { workspace: { team_id: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    get edit_workspace_path(workspaces(:one))
    assert_response :success
  end

  test "update with valid params" do
    workspace = workspaces(:one)
    patch workspace_path(workspace), params: { workspace: { team_name: "Updated" } }
    assert_redirected_to root_path
    assert_equal "Updated", workspace.reload.team_name
  end

  test "destroy deletes workspace" do
    workspace = workspaces(:two)
    assert_difference "Workspace.count", -1 do
      delete workspace_path(workspace)
    end
    assert_redirected_to root_path
  end
end
